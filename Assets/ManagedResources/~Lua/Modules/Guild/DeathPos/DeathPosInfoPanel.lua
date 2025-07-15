----- 公会十绝阵详情面板 -----
require("Base/BasePanel")
local DeathPosInfoPanel = Inherit(BasePanel)
local this = DeathPosInfoPanel

local guildWarConfig=ConfigManager.GetConfig(ConfigName.GuildWarConfig)
local monsterGroup=ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig=ConfigManager.GetConfig(ConfigName.MonsterConfig)
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local monsterViewConfig=ConfigManager.GetConfig(ConfigName.MonsterViewConfig)
local roleConfig=ConfigManager.GetConfig(ConfigName.RoleConfig)

local curIndex=0--当前打开绝阵索引
local rewardList={}--挑战奖励预设容器
local liveNodes={}--立绘容器
local liveNames={}--立绘名容器
local guildName--公会名称

local TabBox = require("Modules/Common/TabBox")
local _TabImgData = {select = "N1_btn_tanke_xuanzhong", default = "N1_btn_tanke_weixuanzhong",}
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1) }
local _TabData = {
    [1]= {txt = GetLanguageStrById(11032)},
    [2]= {txt = GetLanguageStrById(11033)},
}
function DeathPosInfoPanel:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn=Util.GetGameObject(this.panel,"BackBtn")
    this.helpBtn=Util.GetGameObject(this.panel,"HelpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.tabbox = Util.GetGameObject(this.panel, "TabBox")

    --绝阵标题
    this.title=Util.GetGameObject(this.panel,"Title"):GetComponent("Text")
    --当前占据公会名称
    this.curGuildName=Util.GetGameObject(this.panel,"CurGuild/Name"):GetComponent("Text")
    --剩余挑战次数
    this.battleTime=Util.GetGameObject(this.panel,"BattleTime"):GetComponent("Text")

    --敌人阵容组根节点
    this.enemyGrid=Util.GetGameObject(this.panel,"EnemyGrid")
    --英雄预设容器
    this.heroPreList={}
    for i = 1, 6 do
        this.heroPreList[i]=Util.GetGameObject(this.enemyGrid,"Bg"..i.."/Hero"..i)
    end

    --奖励组根节点
    this.rewardGrid=Util.GetGameObject(this.panel,"Reward/Grid")
    --挑战按钮
    this.goBtn=Util.GetGameObject(this.panel,"GoBtn")

    --排名
    this.rankTitle=Util.GetGameObject(this.panel,"Rank/Title/Name"):GetComponent("Text")
    this.rankScroll=Util.GetGameObject(this.panel,"Rank/Scroll")
    this.rankPre=Util.GetGameObject(this.panel,"Rank/Scroll/Pre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.rankScroll.transform,this.rankPre, nil,
    Vector2.New(this.rankScroll.transform.rect.width,this.rankScroll.transform.rect.height),1,1,Vector2.New(0,10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    --我的排名
    this.mRRank=Util.GetGameObject(this.panel,"Rank")
    this.mRSortNum=Util.GetGameObject(this.panel,"Rank/MyRank/SortNum")
    this.mRName=Util.GetGameObject(this.panel,"Rank/MyRank/Name"):GetComponent("Text")
    this.mRHurt=Util.GetGameObject(this.panel,"Rank/MyRank/Hurt"):GetComponent("Text")

    this.empty=Util.GetGameObject(this.panel,"Rank/Empty")
end

function DeathPosInfoPanel:BindEvent()
    Util.AddClick(this.backBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.GuildTenPosInfo,this.helpPosition.x,this.helpPosition.y)
    end)
    --点击挑战
    Util.AddClick(this.goBtn,function()
        if DeathPosManager.status~=DeathPosStatus.Fight then
            PopupTipPanel.ShowTipByLanguageId(11047)
            return
        end
        if DeathPosManager.allowchallange==DeathPosStatus.Belated then
            PopupTipPanel.ShowTipByLanguageId(12259)
            return
        end
        if DeathPosManager.battleTime<=0 then
            PopupTipPanel.ShowTipByLanguageId(11048)
            return
        end
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_DEATHPOS,curIndex)
    end)
end

function DeathPosInfoPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel)
end

function DeathPosInfoPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshPanel)
end
function DeathPosInfoPanel:OnOpen(...)
    local args={...}
    curIndex=args[1]
    guildName=args[2]
end

function DeathPosInfoPanel:OnShow()
    this.RefreshPanel()
end

function DeathPosInfoPanel:OnClose()
    this.empty:SetActive(false)
    for i = 1, #this.heroPreList do
        local o=this.heroPreList[i]
        if liveNodes[o] then
            poolManager:UnLoadLive(liveNames[o], liveNodes[o])
            liveNames[o] = nil
        end
    end
end

function DeathPosInfoPanel:OnDestroy()
    this.scrollView=nil
    rewardList={}
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

function this.RefreshPanel()
    if DeathPosManager.status==DeathPosStatus.Close then
        this:ClosePanel()
        return
    end

    this.curGuildName.text=guildName~="" and guildName or GetLanguageStrById(10094) --设置公会名称 没有占据显示无
    this.title.text=guildWarConfig[curIndex].Name..GetLanguageStrById(11049)
    this.battleTime.text=GetLanguageStrById(11050)..DeathPosManager.battleTime
    this.SetFormation()
    this.SetReward()

    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

--设置敌人编队
function this.SetFormation()
    local monsterGroupId= guildWarConfig[curIndex].MonsterId

    for i, v in pairs(monsterGroup[monsterGroupId].Contents[1]) do
        local o=this.heroPreList[i]
        if v ~= 0 then
            local id=monsterConfig[v].MonsterId
            this.SetCardSingleData(o, id, i, monsterConfig[v])
            o:SetActive(true)
        else
            o:SetActive(false)
        end
    end
end


--设置单个上阵英雄信息
function this.SetCardSingleData(o, heroId, _pos, heroData)
    local bg=Util.GetGameObject(o,"Bg1"):GetComponent("Image")
    local fg=Util.GetGameObject(o,"Bg2"):GetComponent("Image")
    -- local live=Util.GetGameObject(o,"Mask/Live")
    local lv=Util.GetGameObject(o,"lv/Text"):GetComponent("Text")
    local pro=Util.GetGameObject(o,"Pro/Image"):GetComponent("Image")
    local starGrid=Util.GetGameObject(o,"StarGrid")
    local name=Util.GetGameObject(o,"Name/Text"):GetComponent("Text")
    -- local pos=Util.GetGameObject(o,"Pos"):GetComponent("Image")
    local yuanImage=Util.GetGameObject(o,"yuanImage")
    local hp = Util.GetGameObject(o,"hpProgress/hp"):GetComponent("Image")
    local hpPass = Util.GetGameObject(o,"hpProgress/hpPass"):GetComponent("Image")
    local rage = Util.GetGameObject(o,"rageProgress/rage"):GetComponent("Image")
    local live = Util.GetGameObject(o, "Mask/icon"):GetComponent("RawImage")
    local config = heroConfig[heroId]
    local liveName = GetResourcePath(config.Live)
    local roleConfig = ConfigManager.GetConfigData(ConfigName.RoleConfig, heroId)
    local scale = roleConfig.play_liveScale
    local livePos = Vector3.New(roleConfig.offset[1], roleConfig.offset[2], 0) 
    live.texture = CardRendererManager.GetSpineTexture(_pos, liveName, Vector3.one * scale, livePos, true) 
    live.transform.localScale = Vector3.one
    live.transform.localPosition = Vector3.zero

    local zs = Util.GetGameObject(o, "zs")
    local zsName = GetHeroCardStarZs[heroData.Star]
    if zsName == "" then
        zs:SetActive(false)
    else
        zs:SetActive(true)
        zs:GetComponent("Image").sprite = Util.LoadSprite(zsName)
    end

    yuanImage:SetActive(false)
    lv.text=heroData.Level

    bg.sprite = Util.LoadSprite(GetBattleHeroCardStarBg[heroData.Star])
    fg.sprite = Util.LoadSprite(GetHeroCardStarFg[heroData.Star])

    pro.sprite=Util.LoadSprite(GetProStrImageByProNum(heroData.PropertyName))
    SetCardStars(starGrid,heroData.Star)
    name.text=GetLanguageStrById(heroData.ReadingName)

    hp.fillAmount = 1
    hpPass.fillAmount = 1
    rage.fillAmount = 0.5

end

--刷新排行榜 index当前排行类型索引
function this.RefreshRank(index)
    this.rankTitle.text=index==1 and GetLanguageStrById(11046) or GetLanguageStrById(11051)

    local curRankType=RANK_TYPE.GUILD_DEATHPOS_GUILD --默认公会排行
    if index==1 then
        curRankType=RANK_TYPE.GUILD_DEATHPOS_GUILD --公会排行
    elseif index==2 then
        curRankType=RANK_TYPE.GUILD_DEATHPOS_PERSON --个人排行
    end
    NetManager.RequestRankInfo(curRankType,function(msg)
        this.empty:SetActive(#msg.ranks<=0)
        this.scrollView:SetData(msg.ranks,function(index,root)
            this.SetScrollPre(root,msg.ranks[index],curRankType)
        end)
        this.scrollView:SetIndex(1)

        --当我的排名没数据时
        this.mRSortNum:SetActive(msg.myRankInfo.rank~=-1)
        if msg.myRankInfo.rank==-1 then
            this.mRName.text=GetLanguageStrById(10041)
            this.mRHurt.text=""
            return
        end
        this.SetMyRank(msg.myRankInfo,curRankType)
    end,curIndex)
end
--设置每条数据
function this.SetScrollPre(root,data,curRankType)
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    local hurt=Util.GetGameObject(root,"Hurt"):GetComponent("Text")

    this.SetRankingNum(root,data.rankInfo.rank,false)
    if curRankType==RANK_TYPE.GUILD_DEATHPOS_GUILD then
        name.text=string.format(GetLanguageStrById(11052),data.guildName,data.rankInfo.param2) --公会名称（人数） param2 挑战人数
    elseif curRankType==RANK_TYPE.GUILD_DEATHPOS_PERSON then
        name.text=string.format("%s",data.userName)
    end
    hurt.text= DeathPosManager.ChangeDamageForm(data.rankInfo.param1)
end
--设置我的名次
function this.SetMyRank(data,curRankType)
    local guildData = MyGuildManager.GetMyGuildInfo()
    this.SetRankingNum(this.mRRank,data.rank,true)
    if curRankType==RANK_TYPE.GUILD_DEATHPOS_GUILD then
        this.mRName.text=string.format(GetLanguageStrById(11052),guildData.name,data.param2) --param2  人数
    elseif curRankType==RANK_TYPE.GUILD_DEATHPOS_PERSON then
        this.mRName.text=PlayerManager.nickName
    end
    this.mRHurt.text= DeathPosManager.ChangeDamageForm(data.param1) --param1 伤害
end
--设置名次  isMy 是否是设置我的名次
function this.SetRankingNum(root,rank,isMy)
    if rank==-1 then
        -- body
    end
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

--设置挑战奖励
function this.SetReward()
    for index, value in ipairs(guildWarConfig[curIndex].RewardShow) do
        if not rewardList[index] then
            rewardList[index]=SubUIManager.Open(SubUIConfig.ItemView,this.rewardGrid.transform)
        end
        rewardList[index]:OnOpen(false,value,1.1,false,false,false)
        rewardList[index].gameObject:GetComponent("RectTransform").pivot=Vector2.New(0.5,0.5)
    end
end

return DeathPosInfoPanel