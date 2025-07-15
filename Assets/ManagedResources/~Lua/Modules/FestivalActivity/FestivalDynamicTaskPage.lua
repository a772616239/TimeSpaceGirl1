local FestivalDynamicTaskPage = quick_class("FestivalDynamicTaskPage")
local allData={}
local itemsGrid = {}--item重复利用
local singleTaskPre = {}
local this=FestivalDynamicTaskPage
local parent 
local endtime = 0
local bannerType = {
    [1] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_huandushengdan"},--N1   
    [2] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_bowenqiangshi_zh"},--N1
    [3] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_suoxiangpimi_zh"},--N1
    [4] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_shunxiwanbian_zh"},--N1
    [5] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_guruojintang_zh"},--N1
    [6] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_gongwubuke_zh"},--N1
    [7] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_qiguanchanghong_zh"},--N1
    [8] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_changquzhiru_zh"},--N1
    [9] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_gangtiexiongxin_zh"},--N1
    [10] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_duanbingxiangjie_zh"},--N1
    [11] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_ruibukedang_zh"},--N1
    [12] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_shunxiwanbian_zh"},--N1
    [13] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_bowenqiangshi_zh"},--N1
    [14] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_jirentianxiang_zh"},--N1
    [15] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_suoxiangpimi_zh"},--N1
    [16] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_duanbingxiangjie_zh"},--N1
    [17] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_guruojintang_zh"},--N1
    [18] = {compent = "bg1",titilebg1 = "N1_bg_zhuangzhilinyun_gangtiexiongxin_zh"},--m5
    [19] = {compent = "bg1",titilebg1 = "m5_img_huodong_yongzhewudi_beijingtu"},--m5
    [20] = {compent = "bg1",titilebg1 = "m5_img_huodong_qizhuangshanhe_zh"},--m5
    [21] = {compent = "bg1",titilebg1 = "m5_img_huodong_piganlidan_beijingtu"},--m5
    [22] = {compent = "bg1",titilebg1 = "m5_img_huodong_shirupozhu_beijingtu"},--m5
    [23] = {compent = "bg1",titilebg1 = "m5_img_huodong_yiwangwuqian_beijingtu"},--m5
    [24] = {compent = "bg1",titilebg1 = "y_yunchouweiwo_banner_zh"},
    [25] = {compent = "bg1",titilebg1 = "y_yishandaohai_banner_zh"},
    [26] = {compent = "bg1",titilebg1 = "x_xuanjimiaosuan_banner_zh"},
    [27] = {compent = "bg1",titilebg1 = "x_xianglongfuhu_banner2_zh"},
    [28] = {compent = "bg1",titilebg1 = "b_bowenduoshi_banner_zh"},
    [29] = {compent = "bg1",titilebg1 = "t_tianxiangjiren_banner_zh"},
    [30] = {compent = "bg1",titilebg1 = "s_suoxiangpimi_banner_zh"},
    [31] = {compent = "bg1",titilebg1 = "x_xialuxiangfeng_banner_zh"},
    [32] = {compent = "bg1",titilebg1 = "s_suoxiangpimi_banner_zh"},
    [33] = {compent = "bg1",titilebg1 = "x_xialuxiangfeng_banner_zh"},
    [34] = {compent = "bg1",titilebg1 = "t_tongqiangtiebi_banner_zh"},
}
local GlobalActConfig = ConfigManager.GetConfig(ConfigName.GlobalActivity)
function FestivalDynamicTaskPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function FestivalDynamicTaskPage:InitComponent(gameObject)

    itemsGrid = {}--item重复利用
    singleTaskPre = {}
    this.time = Util.GetGameObject(gameObject, "tiao/time"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "itempre")
    this.scrollItem = Util.GetGameObject(gameObject, "grid")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    this.gameObject = gameObject
end

--绑定事件（用于子类重写）
function FestivalDynamicTaskPage:BindEvent()
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.DynamicTask.OnMissionChange, this.Refresh)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.DynamicTask.OnMissionChange, this.Refresh)
end

local sortingOrder = 0
--界面打开时调用（用于子类重写）
function FestivalDynamicTaskPage:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FestivalDynamicTaskPage:OnShow(_sortingOrder,_parent)
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FestivalActivity)
    
    local curindex = GlobalActConfig[id].ShowArt
    for k,v in pairs(bannerType) do
        Util.GetGameObject(this.gameObject, v.compent):SetActive(false)
    end
    Util.GetGameObject(this.gameObject, bannerType[curindex].compent):SetActive(true)
    Util.GetGameObject(this.gameObject, bannerType[curindex].compent):GetComponent("Image").sprite = Util.LoadSprite(bannerType[curindex].titilebg1)
    if bannerType[curindex].titilebg2 and bannerType[curindex].titilebg2 ~= "" then
        Util.GetGameObject(this.gameObject, bannerType[curindex].compent.."/Image"):GetComponent("Image").sprite = Util.LoadSprite(bannerType[curindex].titilebg2)
    end
    sortingOrder = _sortingOrder
    parent =  _parent
    this.Refresh()
end

function this.Refresh()
    allData = OperatingManager:InitDynamicActData()
    this:OnShowData()
    this:SetTime()
end

function FestivalDynamicTaskPage:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local five_timeDown
    local week_timeDown
    five_timeDown = CalculateSecondsNowTo_N_OClock(24)
    week_timeDown = endtime - GetTimeStamp()
    for k,v in pairs(singleTaskPre) do   
        -- v.com.gameObject:SetActive(true)
        if v and v.data.type == 1 then
            if five_timeDown > 3600 then
                v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToH(five_timeDown))
            else
                v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(five_timeDown))
            end
        else
            if week_timeDown > 3600 then
                v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToDH(week_timeDown))
            else
                v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(week_timeDown))
            end
        end     
    end   
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(week_timeDown)
    self.timer = Timer.New(function()
        five_timeDown = five_timeDown - 1
        week_timeDown = week_timeDown - 1
        if five_timeDown <= 0  then
            this.Refresh()
            return
        end
        if week_timeDown <= 0 then
            return
        end
        for k,v in pairs(singleTaskPre) do          
            -- v.com.gameObject:SetActive(true)
            if v and v.data.type == 1 then
                if five_timeDown >= 3600 then
                    v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToH(five_timeDown))
                else
                    v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(five_timeDown))
                end
            else
                if week_timeDown >= 3600 then
                    v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToDH(week_timeDown))
                else
                    v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(week_timeDown))
                end
            end  
        end   
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(week_timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function FestivalDynamicTaskPage:OnShowData()
    if allData then
        endtime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.FestivalActivity)
        this.SortData(allData)

        this.ScrollView:SetData(allData, function (index, go)
            this.SingleDataShow(go, allData[index])
            if not singleTaskPre[go] then
                singleTaskPre[go] = {}
            end
            singleTaskPre[go].com = Util.GetGameObject(go,"btn/Text")
            singleTaskPre[go].data = allData[index]
        end)   
    else
        parent.OnPageTabChange(1)
        PopupTipPanel.ShowTip(GetLanguageStrById(12320))
        return
    end
    
end
local typeIndex = {
    [0] = 1,
    [1]  = 0,
    [2] = 2,
}
function FestivalDynamicTaskPage:SortData()
    if allData==nil then
        return
    end
    table.sort(allData, function(a,b)
        if typeIndex[a.state] == typeIndex[b.state] then
            if a.type == b.type then
                return a.id < b.id
            else
                return a.type < b.type
            end
        else
            return typeIndex[a.state] < typeIndex[b.state]
        end
    end)
end
local type={
    [0]={sprite = "N1_btn_tongyongzhognxing_huangse",text = string.format("<color=#FFFFFFFF>%s</color>",GetLanguageStrById(10023))},--N1
    [1]={sprite = "N1_btn_tongyongxiaoxing_lvse",text = string.format("<color=#FFFFFFFF>%s</color>",GetLanguageStrById(10022))},   --N1
    [2]={sprite = "N1_btn_tongyongzhognxing_huangse",text = string.format("<color=#FFFFFFFF>%s</color>",GetLanguageStrById(10350))},  --N1
    
}
--刷新每一条的显示数据
function this.SingleDataShow(pre,value)
    if pre==nil or value==nil then
        return
    end
    --绑定组件
    local activityRewardGo = pre
    activityRewardGo:SetActive(true)
    local sConFigData = value

    local titleText = Util.GetGameObject(activityRewardGo, "title"):GetComponent("Text")
    titleText.text = sConFigData.title .."("..(sConFigData.progress > sConFigData.value and sConFigData.value or sConFigData.progress) .."/"..sConFigData.value..")"
    local missionText = Util.GetGameObject(activityRewardGo, "mission"):GetComponent("Text")
    missionText.text = sConFigData.content
    local timeText = Util.GetGameObject(activityRewardGo, "btn/Text")

    local reward = Util.GetGameObject(activityRewardGo.gameObject, "reward")
    if (not itemsGrid)  then
        itemsGrid = {}
    end
    if not itemsGrid[pre] then
        itemsGrid[pre] = SubUIManager.Open(SubUIConfig.ItemView,reward.transform)
    end
    itemsGrid[pre]:OnOpen(false, sConFigData.reward, 0.9, false)

    local lingquButton = Util.GetGameObject(activityRewardGo.gameObject, "btn")  
    --0-未完成，1-完成未领取  2-已领取
    local state = sConFigData.state
    timeText:SetActive(state == 0)
    
    local red = Util.GetGameObject(lingquButton.gameObject, "redPoint")
    red:SetActive(state == 1)

    Util.GetGameObject(lingquButton.gameObject, "Button/Text"):GetComponent("Text").text = type[state].text
    Util.GetGameObject(lingquButton.gameObject, "Button").gameObject:SetActive(state ~= 2)
    Util.GetGameObject(lingquButton.gameObject, "image").gameObject:SetActive(state == 2)

    Util.AddOnceClick(Util.GetGameObject(lingquButton.gameObject, "Button"), function()
        if state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.DynamicActTask,sConFigData.id, function(respond)    
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1,function ()
                    this.Refresh()
                    CheckRedPointStatus(RedPointType.DynamicActTask)
                end)
            end)
        elseif state == 0 then
            if sConFigData.jump then
                JumpManager.GoJump(sConFigData.jump)
            end
        end        
    end)
end

--界面打开时调用（用于子类重写）
function FestivalDynamicTaskPage:OnOpen()

end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    --OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GiftBuy, id)
    this.Refresh()
end

function FestivalDynamicTaskPage:OnClose()

end

--界面销毁时调用（用于子类重写）
function FestivalDynamicTaskPage:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
    singleTaskPre = {}
    itemsGrid = {}
end

function FestivalDynamicTaskPage:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
end
--- 将一段时间转换为天时分秒
function FestivalDynamicTaskPage:TimeToDHMS(second)
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

return FestivalDynamicTaskPage