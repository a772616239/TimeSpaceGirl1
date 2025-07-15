local this = {}
local guildHelpConfig = ConfigManager.GetConfig(ConfigName.GuildHelpConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
--初始化组件（用于子类重写）
function this:InitComponent(gameObject)
    this.emptyObj = Util.GetGameObject(gameObject, "GuildAid_GuildAid/emptyObj")
    this.titleText = Util.GetGameObject(gameObject, "GuildAid_GuildAid/titleText"):GetComponent("Text")

    this.ItemPre =  Util.GetGameObject(gameObject, "GuildAid_GuildAid/ItemPre")
    local v2 = Util.GetGameObject(gameObject, "GuildAid_GuildAid/ScrollParentView"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "GuildAid_GuildAid/ScrollParentView").transform,
            this.ItemPre, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(50,-3))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end
this.isClickAid = true
--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.aidBtn, function()

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
    this.isClickAid = true
    this.ShowPanelData()
end
function this.ShowPanelData()
    if MyGuildManager.MyFeteInfo.guildHelpTime < guildHelpConfig[1].HelpTime[1] then
        this.titleText.text = GetLanguageStrById(11002)..guildHelpConfig[1].HelpTime[1] - MyGuildManager.MyFeteInfo.guildHelpTime.."/"..guildHelpConfig[1].HelpTime[1]..")"
    else
        local curNum =  MyGuildManager.MyFeteInfo.guildHelpTime - guildHelpConfig[1].HelpTime[1]
        local item = ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).Expend[1]
        this.titleText.text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,item).Name)..GetLanguageStrById(11003)..guildHelpConfig[1].HelpTime[2] - curNum.."/".. guildHelpConfig[1].HelpTime[2]..")"
    end
    local allMyAidData = MyGuildManager.GetAllGuildHelpInfo()
    if #allMyAidData <= 0 and not MyGuildManager.isPanelRequest then
        MyGuildManager.isPanelRequest = true
        NetManager.GuildHelpGetAllRequest(function (msg)
            allMyAidData = MyGuildManager.GetAllGuildHelpInfo()
            this.ScrollView:SetData(allMyAidData, function (index, go)
                this.SingleHelpAidDataShow(go, allMyAidData[index])
            end)
        end)
    else
        this.ScrollView:SetData(allMyAidData, function (index, go)
            this.SingleHelpAidDataShow(go, allMyAidData[index])
        end)
    end
    this.emptyObj:SetActive(#allMyAidData <= 0)
end
function this.SingleHelpAidDataShow(go,data)
    if not data.type or not itemConfig[data.type] then return end
    Util.GetGameObject(go, "heroPro/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(itemConfig[data.type].Quantity))
    Util.GetGameObject(go, "heroPro/frame/Icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[data.type].ResourceID))
    Util.GetGameObject(go, "heroPro/frame/chipImage"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroChipQuantityImageByquality(itemConfig[data.type].Quantity))
    Util.GetGameObject(go, "heroPro/frame/proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig[data.type].PropertyName))
    Util.GetGameObject(go, "okAid/chipInfo"):GetComponent("Text").text = data.name
    Util.GetGameObject(go, "okAid/getAidText"):GetComponent("Text").text = itemConfig[data.type].Name
    Util.GetGameObject(go, "okAid/getAidText/getAidNumText"):GetComponent("Text").text = "("..data.num.."/"..guildHelpConfig[1].RecourseTime[2]..")"
    Util.GetGameObject(go, "okAid/progressbar/progress"):GetComponent("Image").fillAmount = data.num/guildHelpConfig[1].RecourseTime[2]
    local getRewardBtn = Util.GetGameObject(go, "okAid/getRewardBtn")
    local zongNum = guildHelpConfig[1].HelpTime[1] + guildHelpConfig[1].HelpTime[2]
    Util.GetGameObject(getRewardBtn, "goldAid"):SetActive(MyGuildManager.MyFeteInfo.guildHelpTime >= guildHelpConfig[1].HelpTime[1] and MyGuildManager.MyFeteInfo.guildHelpTime < zongNum)
    if MyGuildManager.MyFeteInfo.guildHelpTime < guildHelpConfig[1].HelpTime[1] then
        --免费
        Util.GetGameObject(getRewardBtn, "Text"):GetComponent("Text").text = GetLanguageStrById(11004)
        Util.AddOnceClick(getRewardBtn, function()
            if this.isClickAid then
                this.isClickAid = false
                NetManager.GuildHelpHelpOtherRequest(data.uid,data.type,function (msg)
                    this.ShowRewardAndRefreshPanel(msg)
                end)
            end
        end)
    elseif MyGuildManager.MyFeteInfo.guildHelpTime >= guildHelpConfig[1].HelpTime[1] and MyGuildManager.MyFeteInfo.guildHelpTime < zongNum then
        --元宝
        Util.GetGameObject(getRewardBtn, "goldAid/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[guildHelpConfig[1].Expend[1]].ResourceID))
        Util.GetGameObject(getRewardBtn, "goldAid/Text"):GetComponent("Text").text = guildHelpConfig[1].Expend[2]
        Util.GetGameObject(getRewardBtn, "Text"):GetComponent("Text").text = GetLanguageStrById(11005)
        Util.AddOnceClick(getRewardBtn, function()
            if this.isClickAid then
                this.isClickAid = false
                if BagManager.GetItemCountById(guildHelpConfig[1].Expend[1]) < guildHelpConfig[1].Expend[2] then
                    PopupTipPanel.ShowTipByLanguageId(11006)
                    return
                end
                NetManager.GuildHelpHelpOtherRequest(data.uid,data.type,function (msg)
                    this.ShowRewardAndRefreshPanel(msg)
                end)
            end
        end)
    else
        Util.GetGameObject(getRewardBtn, "Text"):GetComponent("Text").text = GetLanguageStrById(11005)
        Util.AddOnceClick(getRewardBtn, function()
            PopupTipPanel.ShowTipByLanguageId(11006)
        end)
    end
end
--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end
function  this.ShowRewardAndRefreshPanel(msg)
    local content = {}
    if msg.drop.itemlist ~= nil and #msg.drop.itemlist > 0 then
        for i = 1, #msg.drop.itemlist do
            local itemdata = {}
            itemdata.configData = itemConfig[msg.drop.itemlist[i].itemId]
            itemdata.name = GetLanguageStrById(itemdata.configData.Name)
            itemdata.icon = Util.LoadSprite(GetResourcePath(itemdata.configData.ResourceID))
            itemdata.num = msg.drop.itemlist[i].itemNum
            table.insert(content, itemdata)
        end
    end
    PopupText(content, 0.5, 2)
    --UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
    MyGuildManager.SetSingleGuildHelpguildHelpTimeData()
    this.isClickAid = true
    this.ShowPanelData()
end
return this