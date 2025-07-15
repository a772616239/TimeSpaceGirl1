require("Base/BasePanel")
local LineupRecommend = Inherit(BasePanel)
local this = LineupRecommend
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local lineupList = {}--阵容列表
local receivedList = {}--奖励领取信息

--初始化组件（用于子类重写）
function LineupRecommend:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")

    this.content = Util.GetGameObject(this.gameObject, "Scroll View/Viewport/Content")
    this.prefab = Util.GetGameObject(this.gameObject, "Scroll View/Viewport/Content/prefab")
end

--绑定事件（用于子类重写）
function LineupRecommend:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function LineupRecommend:AddListener()
end

--移除事件监听（用于子类重写）
function LineupRecommend:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LineupRecommend:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LineupRecommend:OnShow()
    NetManager.HeroCollectRewardInfo(function (msg)
        receivedList = msg.infos

        local list = ConfigManager.GetAllConfigsDataByKey(ConfigName.BeStronger, "Type", 5)
        for i, v in ipairs(list) do
            if lineupList[i] == nil then
                lineupList[i] = {
                    prefab = nil,
                    cards = {},
                    rawards = {}
                }
            end
            if lineupList[i].prefab == nil then
                lineupList[i].prefab = newObject(this.prefab)
                lineupList[i].prefab.transform:SetParent(this.content.transform)
                lineupList[i].prefab.transform.localScale = Vector3.one
                lineupList[i].prefab:SetActive(true)
            end
            this.SetPrefabData(lineupList[i].prefab, v, i)
        end
    end)
    CheckRedPointStatus(RedPointType.LineupRecommend)
end

--界面关闭时调用（用于子类重写）
function LineupRecommend:OnClose()
end

--界面销毁时调用（用于子类重写）
function LineupRecommend:OnDestroy()
    lineupList = {}
end

function this.SetPrefabData(go, data, index)
    local iconPanel = Util.GetGameObject(go, "iconPanel")
    local descPanel = Util.GetGameObject(go, "descPanel")
    local title = Util.GetGameObject(iconPanel, "title"):GetComponent("Text")
    local grid = Util.GetGameObject(iconPanel, "grid")
    local hero = Util.GetGameObject(iconPanel, "grid/hero")
    local btnPreview = Util.GetGameObject(iconPanel, "btnPreview")
    local redPoint = Util.GetGameObject(iconPanel, "btnPreview/redpoint")

    title.text = GetLanguageStrById(data.DescFirst)
    local haveNum = 0--拥有英雄数量
    for i, v in ipairs(data.ItemId) do
        if lineupList[index].cards[i] == nil then
            lineupList[index].cards[i] = newObject(hero)
            lineupList[index].cards[i].transform:SetParent(grid.transform)
            lineupList[index].cards[i].transform.localScale = Vector3.one * 0.7
            lineupList[index].cards[i]:SetActive(true)
        end
        local card = lineupList[index].cards[i]
        local config = HeroConfig[v]
        SetHeroBg(Util.GetGameObject(card, "card/card/bg"), Util.GetGameObject(card, "card/card/frame"), config.Quality, config.Star)
        Util.GetGameObject(card, "card/card/lv"):GetComponent("Text").text = 1
        Util.GetGameObject(card, "card/card/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.Painting))
        Util.GetGameObject(card, "card/card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(config.PropertyName))
        Util.GetGameObject(card, "card/card/sign/core"):SetActive(config.HeroValue == 1)
        Util.GetGameObject(card, "location"):GetComponent("Text").text = GetLanguageStrById(config.HeroLocationDesc1)

        local isHave = PlayerManager.heroHandBook and PlayerManager.heroHandBook[v]--是否拥有英雄
        Util.SetGray(Util.GetGameObject(card, "card/card/bg"), not isHave)
        Util.SetGray(Util.GetGameObject(card, "card/card/icon"), not isHave)
        Util.SetGray(Util.GetGameObject(card, "card/card/pro"), not isHave)
        if isHave then haveNum = haveNum + 1 end

        Util.AddOnceClick(Util.GetGameObject(card, "card/card"), function () --英雄信息
            UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, v, config.Star)
        end)
    end
    --红点
    local num = 0
    for _, v in pairs(receivedList) do
        if data.Id == v.id then
            num = #v.indexArray
        end
    end
    redPoint:SetActive(haveNum > num)

    Util.AddOnceClick(btnPreview, function ()
        descPanel:SetActive(not descPanel.activeSelf)
        if descPanel.activeSelf then
            this.SetReward(data, index, go, haveNum)
        end
    end)
end

function this.SetReward(data, index, go, haveNum)
    local descPanel = Util.GetGameObject(go, "descPanel")
    local describe = Util.GetGameObject(descPanel, "describe/Text"):GetComponent("Text")
    local progress = Util.GetGameObject(descPanel, "progress/Text"):GetComponent("Text")
    local slider = Util.GetGameObject(descPanel, "progress/Slider"):GetComponent("Slider")
    local prefab = Util.GetGameObject(descPanel, "prefab")
    local redPoint = Util.GetGameObject(go, "iconPanel/btnPreview/redpoint")

    for i, v in ipairs(data.CollectReward) do
        local item
        if i == #data.CollectReward then
            item = Util.GetGameObject(descPanel, "reward")
            lineupList[index].rawards[i] = item
        else
            if lineupList[index].rawards[i] == nil then
                lineupList[index].rawards[i] = newObject(prefab)
                lineupList[index].rawards[i].transform:SetParent(descPanel.transform)
                lineupList[index].rawards[i].transform.localScale = Vector3.one
                lineupList[index].rawards[i]:SetActive(true)
            end
            item = lineupList[index].rawards[i]
            slider.value = i / #data.CollectReward
            item.transform.position = Util.GetGameObject(slider.gameObject, "Fill Area/Fill/pos").transform.position
            item.transform.localPosition = Vector3.New(item.transform.localPosition.x, item.transform.localPosition.y + 45,0)
        end
        local config = ItemConfig[v[1]]
        Util.GetGameObject(item, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(config.Quantity))
        Util.GetGameObject(item, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.ResourceID))
        Util.GetGameObject(item, "num"):GetComponent("Text").text = v[2]
        Util.GetGameObject(item, "receive"):SetActive(i <= haveNum)

        --已领取
        for _, array in ipairs(receivedList) do
            if data.Id == array.id then
                for _, number in ipairs(array.indexArray) do
                    if number == i then
                        Util.GetGameObject(item, "receive"):SetActive(false)
                        Util.GetGameObject(item, "received"):SetActive(true)
                        Util.SetGray(Util.GetGameObject(item, "frame"), true)
                        Util.SetGray(Util.GetGameObject(item, "icon"), true)
                    end
                end
            end
        end

        Util.AddOnceClick(Util.GetGameObject(item, "frame"), function ()
            NetManager.HeroCollectRewardRequest(data.Id, i, function (msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function()
                    PlayerManager.RefreshreceivedList()
                    NetManager.HeroCollectRewardInfo(function (msg)
                        receivedList = msg.infos
                        this.SetReward(data, index, go, haveNum)

                        --红点
                        local num = 0
                        for _, array in ipairs(receivedList) do
                            if data.Id == array.id then
                                num = #array.indexArray
                            end
                        end
                        redPoint:SetActive(haveNum > num)
                    end)
                end)
            end)
        end)
    end

    describe.text = GetLanguageStrById(data.DescSecond)
    progress.text = haveNum .. "/" .. #data.ItemId
    slider.value = haveNum / #data.ItemId
end

return LineupRecommend