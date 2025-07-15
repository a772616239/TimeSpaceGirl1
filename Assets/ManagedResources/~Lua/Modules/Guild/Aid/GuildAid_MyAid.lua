local this = {}
local guildHelpConfig = ConfigManager.GetConfig(ConfigName.GuildHelpConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local allMyAidData = {}
--初始化组件（用于子类重写）
function this:InitComponent(gameObject)
    this.aidNumText = Util.GetGameObject(gameObject, "GuildAid_MyAid/aidNumText"):GetComponent("Text")
    this.refreshText = Util.GetGameObject(gameObject, "GuildAid_MyAid/refreshText"):GetComponent("Text")
    this.aidBtn = Util.GetGameObject(gameObject, "GuildAid_MyAid/aidBtn")
    this.boxBtn = Util.GetGameObject(gameObject, "GuildAid_MyAid/box")
    this.boxRedPoint = Util.GetGameObject(gameObject, "GuildAid_MyAid/box/redPoint")

    this.ItemPre =  Util.GetGameObject(gameObject, "GuildAid_MyAid/ItemPre")
    local v2 = Util.GetGameObject(gameObject, "GuildAid_MyAid/rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "GuildAid_MyAid/rect").transform,
            this.ItemPre, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(50,-3))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function this:BindEvent()
    BindRedPointObject(RedPointType.Guild_AidBox, this.boxRedPoint)
    Util.AddClick(this.aidBtn, function()
        --您还未进行求援
        local isSend = 0
        for i = 1, #allMyAidData do
            if not allMyAidData[i].type then
                isSend = isSend + 1
            end
        end
        if isSend == #allMyAidData then
            PopupTipPanel.ShowTipByLanguageId(11007)
            return
        end
        local isFinish = 0
        for i = 1, #allMyAidData do
            if allMyAidData[i].num == allMyAidData[i].hadtakenum and allMyAidData[i].hadtakenum == guildHelpConfig[1].RecourseTime[2] then
                isFinish = isFinish + 1
            end
        end
        if isFinish >= 2 then
            PopupTipPanel.ShowTipByLanguageId(12203)
            return
        end
        local itemId1 = nil
        local itemId2 = nil
        if MyGuildManager.MyFeteInfo.guildHelpInfo and #MyGuildManager.MyFeteInfo.guildHelpInfo > 0 then
            for i = 1, #MyGuildManager.MyFeteInfo.guildHelpInfo do
                if not itemId1 then
                    itemId1 = MyGuildManager.MyFeteInfo.guildHelpInfo[i].type
                else
                    itemId2 = MyGuildManager.MyFeteInfo.guildHelpInfo[i].type
                end
            end
        end
        if not MyGuildManager.ShowGuildAidCdTime(false) then
            MyGuildManager.ShowGuildAidCdTime()
            return
        end
        NetManager.GuildSendHelpMessageRequest(function (msg)
            if msg.sendMessage then
                ChatManager.RequestSendGuildAid(itemId1,itemId2,function()
                    PopupTipPanel.ShowTipByLanguageId(11008)
                    MyGuildManager.SetGuildHelpCDTimeData()
                end)
            else
                MyGuildManager.ShowGuildAidCdTime()
            end
        end)
    end)
    Util.AddClick(this.boxBtn, function()
        local isSengGetBoxReward = true
        for i = 1, #allMyAidData do
            if allMyAidData[i].maxNum ~= allMyAidData[i].hadtakenum then
                isSengGetBoxReward = false
            end
        end
        if not MyGuildManager.MyFeteInfo.isTakeGuildHelpReward  and isSengGetBoxReward then
            NetManager.GuildTakeHelpBoxRequest(function (msg)
                MyGuildManager.SetMyAidBoxStateInfo(true)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                end)
            end)
        else
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.GuildAidFindBoxReward,function ()
            end)
        end

    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildAid, this.ShowPanelData)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildAid, this.ShowPanelData)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
    --this
    this.refreshText.text = GetLanguageStrById(11009)
    this.ShowPanelData()
end
function this.ShowPanelData()
    allMyAidData = {}
    for i = 1, guildHelpConfig[1].RecourseTime[1] do
        local GuildHelpInfo = {}
        GuildHelpInfo.type = nil
        GuildHelpInfo.num = nil
        GuildHelpInfo.hadtakenum = nil
        GuildHelpInfo.maxNum = guildHelpConfig[1].RecourseTime[2]
        table.insert(allMyAidData,GuildHelpInfo)
    end
    local curAidNum = 0
    if MyGuildManager.MyFeteInfo.guildHelpInfo and #MyGuildManager.MyFeteInfo.guildHelpInfo > 0 then
        for i = 1, #MyGuildManager.MyFeteInfo.guildHelpInfo do
            local curguildHelpInfo = MyGuildManager.MyFeteInfo.guildHelpInfo[i]
            
            if allMyAidData[i] then
                allMyAidData[i].type = curguildHelpInfo.type
                allMyAidData[i].num = curguildHelpInfo.num
                allMyAidData[i].hadtakenum = curguildHelpInfo.hadtakenum
                
                if allMyAidData[i].num == allMyAidData[i].hadtakenum and allMyAidData[i].hadtakenum == guildHelpConfig[1].RecourseTime[2] then
                    curAidNum = curAidNum + 1
                end
            end
        end
    end
    this.aidNumText.text = GetLanguageStrById(11010)..curAidNum.."/"..guildHelpConfig[1].RecourseTime[1].."）"
    this.ScrollView:SetData(allMyAidData, function (index, go)
        this.SingleHelpDataShow(go, allMyAidData[index])
    end)
end
function this.SingleHelpDataShow(go,data)
    local isHave = data.type ~= nil
    Util.GetGameObject(go, "heroPro/frame"):SetActive(isHave)
    Util.GetGameObject(go, "noAid"):SetActive(not isHave)
    Util.GetGameObject(go, "okAid"):SetActive(isHave)
    Util.GetGameObject(go, "noAid/tipText"):GetComponent("Text").text = GetLanguageStrById(11011)
    if isHave then
        
        Util.GetGameObject(go, "heroPro/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(itemConfig[data.type].Quantity))
        Util.GetGameObject(go, "heroPro/frame/Icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[data.type].ResourceID))
        Util.GetGameObject(go, "heroPro/frame/chipImage"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroChipQuantityImageByquality(itemConfig[data.type].Quantity))
        Util.GetGameObject(go, "heroPro/frame/proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig[data.type].PropertyName))
        Util.GetGameObject(go, "okAid/chipInfo"):GetComponent("Text").text = GetLanguageStrById(itemConfig[data.type].Name)
        Util.GetGameObject(go, "okAid/getAidText/getAidNumText"):GetComponent("Text").text = data.num.."/"..guildHelpConfig[1].RecourseTime[2]
        Util.GetGameObject(go, "okAid/getFinishText"):SetActive(data.num == data.hadtakenum and data.hadtakenum == guildHelpConfig[1].RecourseTime[2])
        Util.GetGameObject(go, "okAid/progressbar/progress1"):GetComponent("Image").fillAmount = data.num/guildHelpConfig[1].RecourseTime[2]
        Util.GetGameObject(go, "okAid/progressbar/progress2"):GetComponent("Image").fillAmount = data.hadtakenum/guildHelpConfig[1].RecourseTime[2]
        local getRewardBtn = Util.GetGameObject(go, "okAid/getRewardBtn")
        getRewardBtn:SetActive(not (data.num == data.hadtakenum and data.hadtakenum == guildHelpConfig[1].RecourseTime[2]))
        Util.SetGray(getRewardBtn, data.num == data.hadtakenum)
        getRewardBtn:GetComponent("Button").enabled =  not (data.num == data.hadtakenum)
        Util.AddOnceClick(getRewardBtn, function()
            NetManager.GuildTakeHelpRewardRequest(data.type,function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                    
                end)
                MyGuildManager.SetMyAidInfoHadtakenum(data.type,data.num - data.hadtakenum)
                this.ShowPanelData()
            end)
        end)
    else
        Util.AddOnceClick(Util.GetGameObject(go, "noAid/clickBtn"), function()
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.GuildAid,function ()
                this.ShowPanelData()
            end)
        end)
    end
end
--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    ClearRedPointObject(RedPointType.Guild_AidBox)
end

return this