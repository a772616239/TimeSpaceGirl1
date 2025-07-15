----- 公会十绝阵排行弹窗 -----
require("Base/BasePanel")
local DeathPosRankPopup = Inherit(BasePanel)
local this = DeathPosRankPopup

--标签按钮
local TabBox = require("Modules/Common/TabBox")
local _TabImgData = {select = "N1_btn_tanke_xuanzhong", default = "N1_btn_tanke_weixuanzhong",}
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1) }
local _TabData = {
    [1]= {txt = GetLanguageStrById(11032)},
    [2]= {txt = GetLanguageStrById(11033)},
}
function DeathPosRankPopup:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn=Util.GetGameObject(this.panel,"BackBtn")
    this.upName=Util.GetGameObject(this.panel,"Scroll/UpInfo/Grid/Name"):GetComponent("Text")
    this.upNum=Util.GetGameObject(this.panel,"Scroll/UpInfo/Grid/Num")

    this.tabbox = Util.GetGameObject(this.panel, "TabBox")

    this.rankScroll=Util.GetGameObject(this.panel,"Scroll/Root")
    this.rankPre=Util.GetGameObject(this.panel,"Scroll/Root/Pre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.rankScroll.transform,this.rankPre, nil,
    Vector2.New(this.rankScroll.transform.rect.width,this.rankScroll.transform.rect.height),1,1,Vector2.New(0,10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    --我的排名
    this.mRRank=Util.GetGameObject(this.panel,"Scroll/MyInfo")
    this.mRSortNum=Util.GetGameObject(this.panel,"Scroll/MyInfo/SortNum")
    this.mRName=Util.GetGameObject(this.panel,"Scroll/MyInfo/Grid/Name"):GetComponent("Text")
    this.mRNum=Util.GetGameObject(this.panel,"Scroll/MyInfo/Grid/Num"):GetComponent("Text")
    this.mRHurt=Util.GetGameObject(this.panel,"Scroll/MyInfo/Hurt"):GetComponent("Text")

    this.empty=Util.GetGameObject(this.panel,"Scroll/Empty")
end

function DeathPosRankPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

function DeathPosRankPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel)
end

function DeathPosRankPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel)
end
function DeathPosRankPopup:OnOpen(...)

end

function DeathPosRankPopup:OnShow()
    this.RefreshPanel()
end

function DeathPosRankPopup:OnClose()
    this.empty:SetActive(false)
end

function DeathPosRankPopup:OnDestroy()
    this.scrollView=nil
end


function this.RefreshPanel()
    if DeathPosManager.status==DeathPosStatus.Close then
        this:ClosePanel()
        return
    end
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "Image")
    local txt = Util.GetGameObject(tab, "Text")
    img:GetComponent("Image").sprite = Util.LoadSprite(_TabImgData[status])
    txt:GetComponent("Text").text = _TabData[index].txt
    txt:GetComponent("Text").color = _TabFontColor[status]
end

-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    this.RefreshRank(index)
end



--刷新排行榜 index当前排行类型索引
function this.RefreshRank(index)
    this.upName.text=index==1 and GetLanguageStrById(11046) or GetLanguageStrById(11051)
    this.upNum:SetActive(index==1)
    local curRankType=RANK_TYPE.GUILD_DEATHPOS_ALLGUILD --默认公会排行
    if index==1 then
        curRankType=RANK_TYPE.GUILD_DEATHPOS_ALLGUILD --公会排行
    elseif index==2 then
        curRankType=RANK_TYPE.GUILD_DEATHPOS_ALLPERSON --个人排行
    end
    NetManager.RequestRankInfo(curRankType,function(msg)
        this.empty:SetActive(#msg.ranks<=0)
        this.scrollView:SetData(msg.ranks,function(index,root)
            this.SetScrollPre(root,msg.ranks[index],curRankType)
        end)
        this.scrollView:SetIndex(1)

        --当我的排名没数据时
        this.mRSortNum:SetActive(msg.myRankInfo.rank~=-1)
        this.mRNum.gameObject:SetActive(msg.myRankInfo.rank~=-1)
        if msg.myRankInfo.rank==-1 then
            this.mRName.text=GetLanguageStrById(10041)
            this.mRHurt.text=""
            return
        end
        this.SetMyRank(msg.myRankInfo,curRankType)
    end)
end

--设置每条数据
function this.SetScrollPre(root,data,curRankType)
    local name=Util.GetGameObject(root,"Grid/Name"):GetComponent("Text")
    local num=Util.GetGameObject(root,"Grid/Num"):GetComponent("Text")
    local hurt=Util.GetGameObject(root,"Hurt"):GetComponent("Text")

    this.SetRankingNum(root,data.rankInfo.rank,false)
    num.gameObject:SetActive(curRankType==RANK_TYPE.GUILD_DEATHPOS_ALLGUILD)
    if curRankType==RANK_TYPE.GUILD_DEATHPOS_ALLGUILD then
        name.text=string.format(GetLanguageStrById(11052),data.guildName,data.rankInfo.param3) --公会名称 人数
        num.text=data.rankInfo.param2 -- param2 挑战人数
    elseif curRankType==RANK_TYPE.GUILD_DEATHPOS_ALLPERSON then
        name.text=data.userName
    end
    hurt.text= DeathPosManager.ChangeDamageForm(data.rankInfo.param1)
end
--设置我的名次
function this.SetMyRank(data,curRankType)
    local guildData = MyGuildManager.GetMyGuildInfo()
    this.SetRankingNum(this.mRRank,data.rank,true)
    this.mRNum.gameObject:SetActive(curRankType==RANK_TYPE.GUILD_DEATHPOS_ALLGUILD)
    if curRankType==RANK_TYPE.GUILD_DEATHPOS_ALLGUILD then
        this.mRName.text=guildData.name
        this.mRNum.text= data.param2..GetLanguageStrById(11057) --param2  人数
    elseif curRankType==RANK_TYPE.GUILD_DEATHPOS_ALLPERSON then
        this.mRName.text=PlayerManager.nickName
    end
    this.mRHurt.text= DeathPosManager.ChangeDamageForm(data.param1) --param1 伤害
end
--设置名次 isMy 是否是设置我的名次
function this.SetRankingNum(root,rank,isMy)
    local sortNumTabs={}
    for i = 1, 4 do
        sortNumTabs[i]=Util.GetGameObject(root,"SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if rank < 4 then
        sortNumTabs[rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        if rank>100 and isMy then
            rank="100+"
        end
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rank
    end
end

return DeathPosRankPopup