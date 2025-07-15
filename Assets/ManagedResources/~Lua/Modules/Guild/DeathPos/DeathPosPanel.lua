----- 公会十绝阵主面板 -----
require("Base/BasePanel")
local DeathPosPanel = Inherit(BasePanel)
local this = DeathPosPanel
local deathPathInfo=nil
local guildWarConfig=ConfigManager.GetConfig(ConfigName.GuildWarConfig)
local _image={"s_shijuezhen_zhanlingbiao","s_shijuezhen_zhanlingbiao_01"}--公会旗帜 1是别人公会 2自己公会
local orginLayer = 0
local orginLayer2 = 0
local d={ --各阵位置信息
    [1]={pos={-33,645}},
    [2]={pos={-364,525}},
    [3]={pos={251,483}},
    [4]={pos={-174,314}},
    [5]={pos={344,188}},
    [6]={pos={0,17}},
    [7]={pos={355,-124}},
    [8]={pos={-342,-231}},
    [9]={pos={291,-576}},
    [10]={pos={-355,-666}},
}
local preList={} --各阵预设列表
function DeathPosPanel:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.overTime=Util.GetGameObject(this.panel,"OverTime/Text"):GetComponent("Text")--挑战结束时间
    this.battleTime=Util.GetGameObject(this.panel,"BattleTime"):GetComponent("Text")--挑战剩余次数
    this.upBtns=Util.GetGameObject(this.panel,"UpBtns")
    this.rewardBtn=Util.GetGameObject(this.upBtns,"RewardBtn")
    this.rewardBtnRedPoint=Util.GetGameObject(this.rewardBtn,"redPoint")
    this.rankBtn=Util.GetGameObject(this.upBtns,"RankBtn")
    this.helpBtn=Util.GetGameObject(this.panel,"HelpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.backBtn=Util.GetGameObject(this.panel,"BackBtn")

    this.content=Util.GetGameObject(this.panel,"Content")
    this.pre=Util.GetGameObject(this.content,"Pre")
end

function DeathPosPanel:BindEvent()
    Util.AddClick(this.backBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.GuildTenPos,this.helpPosition.x,this.helpPosition.y)
    end)
    --奖励弹窗
    Util.AddClick(this.rewardBtn,function()
        UIManager.OpenPanel(UIName.DeathPosRewardPopup)
    end)
    --排行弹窗
    Util.AddClick(this.rankBtn,function()
        UIManager.OpenPanel(UIName.DeathPosRankPopup)
    end)
    if DeathPosManager.status== DeathPosStatus.Reward then
        BindRedPointObject(RedPointType.Guild_DeathPos,this.rewardBtnRedPoint)
    else
        this.rewardBtnRedPoint.gameObject:SetActive(false)
    end
end

function DeathPosPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel) --阶段切换
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshFirstChangeData, this.RefreshGuildInfo)
end

function DeathPosPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshFirstChangeData, this.RefreshGuildInfo)
end
function DeathPosPanel:OnOpen(...)

end

function DeathPosPanel:OnShow()
    -- if DeathPosManager.status== DeathPosStatus.Reward then
    CheckRedPointStatus(RedPointType.Guild_DeathPos)
    -- end
    this.RefreshPanel()
    -- Util.SetParticleSortLayer(Util.GetGameObject(this.panel,"Effect_UI_changjing_ShijueZhen_(Zhong)"), self.sortingOrder)
end
function DeathPosPanel:OnSortingOrderChange()  
    -- Util.SetParticleSortLayer(Util.GetGameObject(this.panel,"Effect_UI_changjing_ShijueZhen_(Zhong)"), self.sortingOrder)
end

function DeathPosPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer=nil
    end
end

function DeathPosPanel:OnDestroy()
    if DeathPosManager.status== DeathPosStatus.Reward then
        ClearRedPointObject(RedPointType.Guild_DeathPos,this.rewardBtnRedPoint)
    end
    preList={}
end

--刷新面板
function this.RefreshPanel()
    if DeathPosManager.status==DeathPosStatus.Close then
        this:ClosePanel()
        return
    end
    this.battleTime.gameObject:SetActive(DeathPosManager.status==DeathPosStatus.Fight)
    for i = 1, 10 do
        local o=preList[i]
        if not o then
            o=newObjToParent(this.pre,this.content.transform)
            o.name="Pre"..i
            preList[i]=o
        end
        local guildName=Util.GetGameObject(o,"Guild/GuildName"):GetComponent("Text")
        local posName=Util.GetGameObject(o,"Name/Text"):GetComponent("Text")
        guildName.text= GetLanguageStrById(12540)
        -- posName.sprite=Util.LoadSprite(guildWarConfig[i].Pic)--guildWarConfig[i].Name
        posName.text = guildWarConfig[i].Name
        preList[i].transform.localPosition=Vector2.New(d[i].pos[1],d[i].pos[2])
        -- Util.GetGameObject(o,"Guild"):SetActive(false)
    end

    NetManager.GetDeathPathInfoResponse(function(msg)
        if DeathPosManager.status==DeathPosStatus.Reward then
            this.overTime.text=GetLanguageStrById(11053)
        elseif DeathPosManager.status==DeathPosStatus.Close then
            this.overTime.text=GetLanguageStrById(11054)
        else
            this.TimeCountDown(msg.overTime)
        end
        DeathPosManager.rewardTimeTip=GetLanguageStrById(11055)..TimeStampToDateStr(GetTimeStamp()+(msg.overTime-GetTimeStamp()))..GetLanguageStrById(11056)
        DeathPosManager.battleTime=DeathPosManager.maxBattleTime-msg.challengeCount
        this.battleTime.text=GetLanguageStrById(11050).. DeathPosManager.battleTime
        DeathPosManager.SetGuildInfoData(msg.infos)
        --设置公会上了哪个阵 显示公会名称
        this.RefreshGuildInfo()
    end)

    --各阵型点击事件
    for i = 1, #preList do
        Util.AddOnceClick(preList[i],function()
            local guildName=Util.GetGameObject(preList[i],"Guild/GuildName"):GetComponent("Text")
            UIManager.OpenPanel(UIName.DeathPosInfoPanel,i,guildName.text)
        end)
    end
end

--倒计时
function this.TimeCountDown(timeDown)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.overTime.text = GetLanguageStrById(10028)..TimeToHMS(timeDown-GetTimeStamp())
    this.timer = Timer.New(function()
        if timeDown < 1 then
            this.timer:Stop()
            this.timer = nil
            --结束逻辑
            this.RefreshPanel()
            return
        end
        this.overTime.text =  GetLanguageStrById(10028)..TimeToHMS(timeDown-GetTimeStamp())
    end, 1, -1, true)
    this.timer:Start()
end

--刷新公会信息
function this.RefreshGuildInfo()
    local data=DeathPosManager.GetGuildInfoData()
    for i = 1, #preList do
        for key, value in pairs(data) do
            if i==value.pathId then
                local guild=Util.GetGameObject(preList[i],"Guild")
                local guildImage=guild:GetComponent("Image")
                local guildName=Util.GetGameObject(preList[i],"Guild/GuildName"):GetComponent("Text")
                guild:SetActive(true)
                guildName.text = GetLanguageStrById(12541) .. value.guildName
                --如果是自己的公会
                guildImage.sprite= value.gid==PlayerManager.familyId and Util.LoadSprite(_image[2]) or Util.LoadSprite(_image[1])
            end
        end
    end
end
return DeathPosPanel