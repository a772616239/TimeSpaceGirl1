----- 公会十绝阵奖励弹窗 -----
require("Base/BasePanel")
local DeathPosRewardPopup = Inherit(BasePanel)
local this = DeathPosRewardPopup
local itemViewList={}
local tempData={}

function DeathPosRewardPopup:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn=Util.GetGameObject(this.panel,"BackBtn")
    this.scroll=Util.GetGameObject(this.panel,"Scroll")
    this.pre=Util.GetGameObject(this.scroll,"Pre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scroll.transform,
    this.pre,nil,Vector2.New(this.scroll.transform.rect.width,this.scroll.transform.rect.height),1,3,Vector2.New(10,5))--生成滚动条，设置属性
    --设置滚动条
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.empty=Util.GetGameObject(this.panel,"Empty")
    this.timeTip=Util.GetGameObject(this.panel,"TimeTip"):GetComponent("Text")
end

function DeathPosRewardPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

function DeathPosRewardPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshDeathPosReward, this.SetIndicationData)
end

function DeathPosRewardPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshDeathPosReward, this.SetIndicationData)
end
function DeathPosRewardPopup:OnOpen(...)

end

function DeathPosRewardPopup:OnShow()
    if DeathPosManager.status==DeathPosStatus.Close then
        this:ClosePanel()
        return
    end
    if DeathPosManager.status== DeathPosStatus.Fight then
        return
    end
    this.empty:SetActive(false)
    this.timeTip.gameObject:SetActive(DeathPosManager.status==DeathPosStatus.Reward)
    NetManager.GetAllDeathPathRewardInfoResponse(function(msg)
        DeathPosManager.SetRewardData(msg.info)
        this.RefreshPanel(DeathPosManager.GetRewardData(),false)
    end)
end

function DeathPosRewardPopup:OnClose()
    tempData={}
    CheckRedPointStatus(RedPointType.Guild_DeathPos)
end

function DeathPosRewardPopup:OnDestroy()
    this.scrollView=nil
end

--其他玩家点击领取奖励的indication推送
function this.SetIndicationData()
    local data=DeathPosManager.GetDoRewardData()
    this.RefreshPanel(data,true)
end

--刷新面板 isI 是否是Indication推送
function this.RefreshPanel(data,isI)

    this.timeTip.text=DeathPosManager.rewardTimeTip
    if isI then --indication推送 只翻牌单一数据
        for i = 1, #tempData do
            if tempData[i].position==data.position then
                tempData[i]=data
            end
        end
    else --上来主动获取数据
        for i = 1, #data do
           
            local isHave = false
            for j=1, #data do
                if data[j].position>0 and data[j].position==i then
                    -- if not data[j] then
                        isHave = true
                        table.insert(tempData,data[j])
                    -- end
                end
            end
            if not isHave then
                table.insert(tempData,{uid=0,username = "",position=i})
            end
        end
    end
    DeathPosManager.SetMyRewardData(tempData)
    this.scrollView:SetData(tempData,function(index,root)
        this.SetScrollPre(root,tempData[index],index)
    end)
    this.scrollView:SetIndex(1)
    this.empty:SetActive(#tempData <= 0)
end

--设置每个预设
function this.SetScrollPre(root,data,index)
    local itemRoot=Util.GetGameObject(root,"Root")
    local lock=Util.GetGameObject(itemRoot,"Lock")
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    local btn=Util.GetGameObject(root,"Bg")

    if data.username~="" then
        
    else
        
    end
    lock:SetActive(data.username=="")
    if data.username=="" then
        name.text=GetLanguageStrById(11058)
    else
        name.text=data.uid==PlayerManager.uid and "<color=#FF8345>"..data.username.."</color>" or "<color=#FFBB62>"..data.username.."</color>"
    end
    name.text=data.username=="" and GetLanguageStrById(11059) or data.username
    btn:GetComponent("Button").interactable=data.username==""

    Util.AddOnceClick(btn,function()
        if DeathPosManager.GetIsGeted(tempData) then
            PopupTipPanel.ShowTipByLanguageId(11060)
            return
        end
        if DeathPosManager.GetIsTakeIn()==false then
            PopupTipPanel.ShowTipByLanguageId(11061)
            return
        end
        NetManager.DoRewardDeathPathRequest(index,function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                -- this.RefreshPanel()
                
            end)
        end)
    end)
    if data.username=="" then
        return
    end

    if not itemViewList[root] then
        itemViewList[root]=SubUIManager.Open(SubUIConfig.ItemView,itemRoot.transform)
    end
    itemViewList[root]:OnOpen(false,{data.itemId,data.itemCount},1.1,false,false,false)

    if data.username then
        name.text=data.username
    end
end



return DeathPosRewardPopup