----- 公会祭祀弹窗 -----
require("Base/BasePanel")
local GuildFetePopup = Inherit(BasePanel)
local this = GuildFetePopup
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local guildSacrificeConfig=ConfigManager.GetConfig(ConfigName.GuildSacrificeConfig)
local guildSacrificeRewardConfig=ConfigManager.GetConfig(ConfigName.GuildSacrificeRewardConfig)
local _ItemViewList={}--reward itemview容器
local sortingOrder=0 --层级
local triggerCallBack --回调
local _isClick=false --是否已祭祀
local feteType=0--祭祀类型
local curValue=0

function GuildFetePopup:InitComponent()
    this.panel = Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn = Util.GetGameObject(this.panel, "BackBtn")
    this.helpBtn = Util.GetGameObject(this.panel,"HelpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    -- this.title = Util.GetGameObject(this.panel,"Title"):GetComponent("Text")
    this.tip = Util.GetGameObject(this.panel,"Tip"):GetComponent("Text")

    this.sliderRoot = Util.GetGameObject(this.panel,"SliderRoot")
    this.slider = Util.GetGameObject(this.sliderRoot, "Slider"):GetComponent("Slider")
    this.sliderValueNum = Util.GetGameObject(this.sliderRoot,"Value/Num"):GetComponent("Text")--祭祀进度值
    this.rewardBox = Util.GetGameObject(this.sliderRoot,"RewardBox")--奖励盒根节点
    this.s_reward={} --进度条奖励组预设
    for i = 1, 3 do
        this.s_reward[i] = Util.GetGameObject(this.rewardBox,"Item"..i)
    end

    this.rewardPanel = Util.GetGameObject(this.panel,"RewardPanel")
    this.rewardPanelBtn = Util.GetGameObject(this.rewardPanel,"CloseBtn")--奖励面板关闭按钮

    this.content = Util.GetGameObject(this.panel,"Content")
    this.feteList = {}--祭祀项预设
    for j = 1, 3 do
        this.feteList[j] = Util.GetGameObject(this.content,"Item"..j)
    end

    this.info = Util.GetGameObject(this.panel, "info")
    this.SliderExp = Util.GetGameObject(this.info, "Slider"):GetComponent("Slider")
    this.SliderExpValue = Util.GetGameObject(this.info, "Slider/Exp"):GetComponent("Text")
    this.Lv = Util.GetGameObject(this.info, "GuildLevel"):GetComponent("Text")
    this.LvNext = Util.GetGameObject(this.info, "GuildNextLevel"):GetComponent("Text")

end

function GuildFetePopup:BindEvent()
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.GuildFete,this.helpPosition.x,this.helpPosition.y)
    end)
end


function GuildFetePopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.OnRefreshFeteProcess, this.RefreshCurValue)
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.RefreshPanel)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DataUpdate, this.RefreshPanel)
end

function GuildFetePopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.OnRefreshFeteProcess, this.RefreshCurValue)
    Game.GlobalEvent:RemoveEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.RefreshPanel)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.DataUpdate, this.RefreshPanel)
end

function GuildFetePopup:OnSortingOrderChange()
    sortingOrder = self.sortingOrder
    -- this.rewardBox:GetComponent("Canvas").sortingOrder = sortingOrder + 1
end

function GuildFetePopup:OnOpen(...)

end

function GuildFetePopup:OnShow()
    CheckRedPointStatus(RedPointType.Guild_Fete)
    -- MyGuildManager.MyFeteInfo.score= MyGuildManager.MyGuildInfo.fete--登录时的奖励进度信息 后续数据刷新由MyGuildManager.MyFeteInfo.score操作
    curValue=MyGuildManager.MyFeteInfo.score
    this.RefreshPanel()
end

function GuildFetePopup:OnClose()
    CheckRedPointStatus(RedPointType.Guild_Fete)
end


function GuildFetePopup:OnDestroy()
    this.s_reward={}
    this.feteList={}
end

function this.RefreshCurValue()
    curValue=MyGuildManager.MyFeteInfo.score
    this.RefreshSlider()
end

--刷新面板
function this.RefreshPanel()
    feteType=MyGuildManager.MyFeteInfo.lastFeteType
    _isClick=feteType~=0 --不为0为已祭祀了

    this.RefreshSlider()
    this.RefreshContent()

    local curGuildLevelInfo = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, MyGuildManager.MyGuildInfo.levle)
    this.SliderExp = Util.GetGameObject(this.info, "Slider"):GetComponent("Slider")
    this.Lv.text = string.format(GetLanguageStrById(22318), MyGuildManager.MyGuildInfo.levle)
    this.SliderExp.value = MyGuildManager.MyGuildInfo.exp / curGuildLevelInfo.Exp
    this.SliderExpValue.text = MyGuildManager.MyGuildInfo.exp .. "/" .. curGuildLevelInfo.Exp

    local curGuildLevelInfoNext = ConfigManager.TryGetConfigData(ConfigName.GuildLevelConfig, MyGuildManager.MyGuildInfo.levle + 1)
    if curGuildLevelInfoNext then
        this.LvNext.text = string.format(GetLanguageStrById(12722), curGuildLevelInfoNext.Num)
    else
        this.LvNext.text = GetLanguageStrById(10267)
    end
    
end


--刷新进度条
function this.RefreshSlider()
    local maxValue=guildSacrificeRewardConfig[3].Score --最大进度
    this.slider.value = curValue/maxValue
    this.sliderValueNum.text = curValue

    -- this.rewardBox:GetComponent("Canvas").sortingOrder = sortingOrder + 1
    for i = 1, #this.s_reward do
        local value = Util.GetGameObject(this.s_reward[i],"Value"):GetComponent("Text")
        local getFinish = Util.GetGameObject(this.s_reward[i],"GetFinish")
        local baoxiang = Util.GetGameObject(this.s_reward[i],"Image")
        local redPoint = Util.GetGameObject(this.s_reward[i],"redPoint")

        this.s_reward[i].transform:DOAnchorPosX(guildSacrificeRewardConfig[i].Pos,0)
        value.text = guildSacrificeRewardConfig[i].Score

        --是否已领取
        local isBuy=false
        for key, v in ipairs(MyGuildManager.MyFeteInfo.takeFeteReward) do
            if v==i and MyGuildManager.MyGuildInfo.id == MyGuildManager.MyFeteInfo.lastFeteGuildId then
                isBuy=true
            end
        end
        getFinish:SetActive(isBuy)
        baoxiang:SetActive(not isBuy)
        if curValue >= guildSacrificeRewardConfig[i].Score and isBuy==false then --领取
            if MyGuildManager.MyFeteInfo.lastFeteType > 0 
            and MyGuildManager.MyGuildInfo.id == MyGuildManager.MyFeteInfo.lastFeteGuildId then
                redPoint:SetActive(true)
            end
            value.text=GetLanguageStrById(10471)
            Util.AddOnceClick(this.s_reward[i],function()
                if MyGuildManager.MyFeteInfo.lastFeteType==0 then
                    PopupTipPanel.ShowTipByLanguageId(10857)
                    return
                end
                if MyGuildManager.MyGuildInfo.id ~= MyGuildManager.MyFeteInfo.lastFeteGuildId then
                    PopupTipPanel.ShowTipByLanguageId(10858)
                    return
                end
                NetManager.FamilyGetFeteRewardRequest(i,function(msg)
                    table.insert(MyGuildManager.MyFeteInfo.takeFeteReward,i)
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function ()
                        this.RefreshPanel()
                    end)
                end)
            end)
        else
            redPoint:SetActive(false)
            Util.AddOnceClick(this.s_reward[i],function()--打开奖励弹窗
                this.SetRewardPanel(i)
            end)
        end
    end
end
--设置奖励面板
function this.SetRewardPanel(i)
    if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    end

    local panel =  UIManager.OpenPanel(UIName.RewardPreviewPopupPanel,{title=GetLanguageStrById(10859),reward=guildSacrificeRewardConfig[i].RewardPreview})
    panel:SetPosition(Vector2.New(0,136))

    -- this.rewardBox:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    triggerCallBack = function (panelType, p)
        if panelType == UIName.RewardPreviewPopupPanel and panel == p then --监听到SkillInfoPopup关闭，把层级设回去
            -- this.rewardBox:GetComponent("Canvas").sortingOrder =sortingOrder + 1
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
        end
    end
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
end

--刷新祭祀内容
function this.RefreshContent()
    for i = 1, #this.feteList do
        local o = this.feteList[i]
        -- local title=Util.GetGameObject(o,"Title"):GetComponent("Text")
        local reward = Util.GetGameObject(o,"Reward")
        local coin = Util.GetGameObject(o,"BuyBtn/Coin")
        local coinImage = Util.GetGameObject(o,"BuyBtn/Coin/Image"):GetComponent("Image")
        local coinNum = Util.GetGameObject(o,"BuyBtn/Coin/Num"):GetComponent("Text")
        local buyBtn = Util.GetGameObject(o,"BuyBtn")
        -- local buyText = Util.GetGameObject(o,"BuyBtn/Text"):GetComponent("Text")
        local goed = Util.GetGameObject(o,"Goed")--已祭祀

        local reward1Txt = Util.GetGameObject(o,"reward1/num"):GetComponent("Text")
        local reward2Txt = Util.GetGameObject(o,"reward2/num"):GetComponent("Text")
        local reward1Img = Util.GetGameObject(o,"reward1/Image"):GetComponent("Image")
        local itemid = guildSacrificeConfig[i].Reward[1][1]
        reward1Img.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemid].ResourceID))

        reward1Txt.text = guildSacrificeConfig[i].Reward[1][2]
        reward2Txt.text = guildSacrificeConfig[i].GuildExperience

        -- title.text=guildSacrificeConfig[i].Name
        --奖励预览
        for index, v in pairs(guildSacrificeConfig[i].Reward) do
            if not _ItemViewList[o] then
                _ItemViewList[o] = {}
            end
            if not _ItemViewList[o][index] then
                _ItemViewList[o][index] = SubUIManager.Open(SubUIConfig.ItemView, reward.transform)
            end
            _ItemViewList[o][index]:OnOpen(false,v,0.85,false,false,false,this.selfsortingOrder)
            _ItemViewList[o][index].gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
        end
        local _needId = guildSacrificeConfig[i].Expend[1][1]--消耗物品Id
        local _needNum = guildSacrificeConfig[i].Expend[1][2]--消耗数量
        coinImage.sprite = Util.LoadSprite(GetResourcePath(itemConfig[_needId].ResourceID))
        --已有金币<消耗金币 变红
        if BagManager.GetItemCountById(_needId)<_needNum then
            coinNum.text="<color=red>".._needNum.."</color>"
        else
            coinNum.text=_needNum
        end
        --已祭祀表现(其它祭祀)
        buyBtn:GetComponent("Button").interactable = not _isClick
        Util.SetGray(buyBtn,_isClick)
        -- buyText.text= _isClick and GetLanguageStrById(12701) or GetLanguageStrById(12700)
        -- buyText.text= GetLanguageStrById(12700)
        --(当前祭祀)
        -- buyBtn:SetActive(i~=feteType)
        -- coin:SetActive(i~=feteType)
        goed:SetActive(i == feteType)


        Util.AddOnceClick(buyBtn,function()
            if BagManager.GetItemCountById(_needId) < _needNum then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),GetLanguageStrById(itemConfig[_needId].Name)))
                return
            end
            NetManager.FamilyFeteRequest(i,function(msg)
                MyGuildManager.MyFeteInfo.lastFeteType=i
                MyGuildManager.MyFeteInfo.lastFeteGuildId=MyGuildManager.MyGuildInfo.id

                --> 本地更新add 服务器未推
                local curGuildLevelInfo = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, MyGuildManager.MyGuildInfo.levle)
                MyGuildManager.MyGuildInfo.exp = MyGuildManager.MyGuildInfo.exp + guildSacrificeConfig[i].GuildExperience
                if MyGuildManager.MyGuildInfo.exp >= curGuildLevelInfo.Exp then
                    MyGuildManager.MyGuildInfo.exp = MyGuildManager.MyGuildInfo.exp - curGuildLevelInfo.Exp
                    MyGuildManager.MyGuildInfo.levle = MyGuildManager.MyGuildInfo.levle + 1
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)

                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function ()
                    PopupTipPanel.ShowTipByLanguageId(10862)
                    this.RefreshPanel()
                end)
            end)
        end)
    end
end

return GuildFetePopup