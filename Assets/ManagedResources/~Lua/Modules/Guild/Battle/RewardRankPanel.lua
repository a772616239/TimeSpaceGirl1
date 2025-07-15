RewardRankPanel = quick_class("GuildBattlePanel")
local this = RewardRankPanel
local guildWarRewardConfig = ConfigManager.GetAllConfigsData(ConfigName.GuildWarRewardConfig)

local itemList = {}
local type = 2 --1：我的 2：公会

function this:InitComponent(go)
    this.gameObject = go
    this.btnPreview = Util.GetGameObject(this.gameObject, "guildRank/btnPreview")--奖池预览
    this.myRank = Util.GetGameObject(this.gameObject, "myRank")
    this.guildRank = Util.GetGameObject(this.gameObject, "guildRank/guild")

    this.itemPre = Util.GetGameObject(this.gameObject, "ItemPre")--个人奖励预制
    this.scroll1 = Util.GetGameObject(this.gameObject, "scroll1")
    local w = this.scroll1.transform.rect.width
    local h = this.scroll1.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll1.transform, this.itemPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.scroll2 = Util.GetGameObject(this.gameObject, "scroll2")
    this.guildItemPre = Util.GetGameObject(this.gameObject, "GuildItemPre")--公会奖励预制
    local w = this.scroll2.transform.rect.width
    local h = this.scroll2.transform.rect.height
    this.guildScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll2.transform, this.guildItemPre, nil,
        Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.guildScrollView.moveTween.MomentumAmount = 1
    this.guildScrollView.moveTween.Strength = 2

    this.select = Util.GetGameObject(this.gameObject, "tab/select")
    this.btn1 = Util.GetGameObject(this.gameObject, "tab/btn1")
    this.btn2 = Util.GetGameObject(this.gameObject, "tab/btn2")
end

function this:BindEvent()
    Util.AddClick(this.btn1, function ()
        type = 2
        this.SetTab()
    end)
    Util.AddClick(this.btn2, function ()
        type = 1
        this.SetTab()
    end)
    Util.AddClick(this.btnPreview, function ()
        UIManager.OpenPanel(UIName.PublicAwardPoolPreviewPanel)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

-- 打开时调用
function this:OnOpen()
end

--界面打开时调用（用于子类重写）
function this:OnShow(index)
    type = index and index or 2
    this.SetTab()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

function this.SetTab()
    if type == 2 then
        this.select.transform.localPosition = this.btn1.transform.localPosition
        Util.GetGameObject(this.select, "Text"):GetComponent("Text").text = Util.GetGameObject(this.btn1, "Text"):GetComponent("Text").text
    else
        this.select.transform.localPosition = this.btn2.transform.localPosition
        Util.GetGameObject(this.select, "Text"):GetComponent("Text").text = Util.GetGameObject(this.btn2, "Text"):GetComponent("Text").text
    end
    this.SetReward()
end

function this.SetReward()
    local rewards = {}
    for i, v in ipairs(guildWarRewardConfig) do
        if v.Mode == 1 and v.Type == type then
            table.insert(rewards, v)
        end
    end
    this.scroll1:SetActive(type == 1)
    this.scroll2:SetActive(type == 2)
    this.guildRank:SetActive(type == 2)
    if type == 1 then
        this.scrollView:SetData(rewards, function(i, go)
            this.SetScrollPre(go, rewards[i], rewards, i)
        end)
        this.scrollView:SetIndex(1)
    else

        this.guildScrollView:SetData(rewards, function(i, go)
            this.SetGuildScrollPre(go, rewards[i], rewards, i)
        end)
        this.guildScrollView:SetIndex(1)
    end
    GuildBattleManager.GetMyGuildRank(function ()
        GuildBattleManager.GetTotalDamageRankRequest(function ()
            this.SetMyRank(rewards)
        end)
    end)
end

local rankImg = {
    "cn2-X1_tongyong_diyi",
    "cn2-X1_tongyong_dier",
    "cn2-X1_tongyong_disan"
}
function this.SetScrollPre(go, data, allData, index)
    go:SetActive(true)
    local rank1 = Util.GetGameObject(go, "rank/rank1"):GetComponent("Image")
    local rank2 = Util.GetGameObject(go, "rank/rank2"):GetComponent("Text")
    local itemGrid = Util.GetGameObject(go, "ItemGrid")

    rank1.gameObject:SetActive(data.Section <= 3)
    rank2.text = ""
    if data.Section <= 3 then
        rank1.sprite = Util.LoadSprite(rankImg[data.Section])
    else
        if data.Section > 100 then
            rank2.text = allData[index - 1].Section.."+"
        else
            rank2.text = (allData[index - 1].Section + 1).."~"..data.Section
        end
    end

    for i = 1, #data.Reward do
        if not itemList[go] then
            itemList[go] = {}
        end
        if not itemList[go][i] then
            itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGrid.transform)
        end
        itemList[go][i]:OnOpen(false, data.Reward[i], 0.55)
    end
end

function this.SetGuildScrollPre(go, data, allData, index)
    go:SetActive(true)
    local rank1 = Util.GetGameObject(go, "rank/rank1"):GetComponent("Image")
    local rank2 = Util.GetGameObject(go, "rank/rank2"):GetComponent("Text")
    local rankReward = Util.GetGameObject(go, "rankReward")
    local boxReward = Util.GetGameObject(go, "boxReward/pos")

    rank1.gameObject:SetActive(data.Section <= 3)
    rank2.text = ""
    if data.Section <= 3 then
        rank1.sprite = Util.LoadSprite(rankImg[data.Section])
    else
        if data.Section > 100 then
            rank2.text = allData[index - 1].Section.."+"
        else
            rank2.text = allData[index - 1].Section.."~"..data.Section
        end
    end

    for i = 1, #data.Reward do
        if not itemList[go] then
            itemList[go] = {}
        end
        if not itemList[go][i] then
            itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, rankReward.transform)
        end
        itemList[go][i]:OnOpen(false, data.Reward[i], 0.55)
    end

    if not itemList[go][#data.Reward+1] then
        itemList[go][#data.Reward+1] = SubUIManager.Open(SubUIConfig.ItemView, boxReward.transform)
    end
    itemList[go][#data.Reward+1]:OnOpen(false, data.RewardBoxShow[1], 0.55)
end

function this.SetMyRank(rewards)
    local rank
    if type == 2 then
        rank = GuildBattleManager.myGuildRank
    else
        rank = GuildBattleManager.myHurtRank
    end
    local title = Util.GetGameObject(this.myRank, "title/Text"):GetComponent("Text")
    local rank1 = Util.GetGameObject(this.myRank, "rank/rank1"):GetComponent("Image")
    local rank2 = Util.GetGameObject(this.myRank, "rank/rank2"):GetComponent("Text")
    local itemGrid = Util.GetGameObject(this.myRank, "ItemGrid")
    local boxReward = Util.GetGameObject(this.myRank, "boxReward")
    local pos = Util.GetGameObject(this.myRank, "boxReward/pos")
    local img = Util.GetGameObject(this.myRank, "boxReward/Image")

    if type == 2 then
        title.text = GetLanguageStrById(50253)--"我的公会"
    else
        title.text = GetLanguageStrById(10104)--"我的排名"
    end
    boxReward:SetActive(type == 2)
    img:SetActive(false)
    rank1.gameObject:SetActive(rank <= 3 and rank > 0)
    rank2.text = ""
    if rank <= 3 and rank > 0 then
        rank1.sprite = Util.LoadSprite(rankImg[rank])
    elseif rank == 0 then
        rank2.text = GetLanguageStrById(10041)--"未上榜"
    else
        rank2.text = rank
    end

    local config = {Reward = {}}
    if rank > 0 then
        for i = 1, #rewards do
            if rank <= rewards[i].Section then
                config = rewards[i]
                break
            elseif rank >= rewards[#rewards].Section then
                config = rewards[i]
                break
            end
        end
    end

    if itemList[this.myRank] then
        for i = 1, #itemList[this.myRank] do
            itemList[this.myRank][i].gameObject:SetActive(false)
        end
    end
    for i = 1, #config.Reward do
        if not itemList[this.myRank] then
            itemList[this.myRank] = {}
        end
        if not itemList[this.myRank][i] then
            itemList[this.myRank][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGrid.transform)
        end
        itemList[this.myRank][i]:OnOpen(false, config.Reward[i], 0.55)
        itemList[this.myRank][i].gameObject:SetActive(true)
    end

    --战果宝箱
    if type == 2 then
        if config.RewardBoxShow and config.RewardBoxShow[1] then
            if not itemList[this.myRank] then
                itemList[this.myRank] = {}
            end
            if not itemList[this.myRank][#itemList[this.myRank]+1] then
                itemList[this.myRank][#itemList[this.myRank]+1] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
            end
            itemList[this.myRank][#itemList[this.myRank]]:OnOpen(false, config.RewardBoxShow[1], 0.55)
            itemList[this.myRank][#itemList[this.myRank]].gameObject:SetActive(true)
            img:SetActive(true)
        end
    end
end

return this