require("Base/BasePanel")
DefenseTrainingRankPopup = Inherit(BasePanel)
local this = DefenseTrainingRankPopup

local _tabIdx = 1
local TabBox = require("Modules/Common/TabBox") -- 引用

local _TabData = {
    [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", name = GetLanguageStrById(12556),title = "cn2-X1_jingjichang_paihangyeqian" },
    [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", name = GetLanguageStrById(10080),title = "cn2-X1_jingjichang_richangjiangli" },
}
local rankPicArray = {
    "cn2-X1_tongyong_diyi",
    "cn2-X1_tongyong_dier",
    "cn2-X1_tongyong_disan",
}

--初始化组件（用于子类重写）
function DefenseTrainingRankPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")

    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox")
    this.RANK = Util.GetGameObject(self.gameObject, "RANK")
    this.REWARD = Util.GetGameObject(self.gameObject, "REWARD")

    --> 排行
    this.Scroll_1 = Util.GetGameObject(self.gameObject, "RANK/Scroll")
    this.RankUserPre = Util.GetGameObject(self.gameObject, "RANK/RankUserPre")
    local w = this.Scroll_1.transform.rect.width
    local h = this.Scroll_1.transform.rect.height
    this.scrollView_1 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll_1.transform, this.RankUserPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.scrollView_1.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView_1.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView_1.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView_1.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView_1.moveTween.MomentumAmount = 1
    this.scrollView_1.moveTween.Strength = 2

    this.MyRankUser = Util.GetGameObject(self.gameObject, "RANK/MyRankUser")
    this.MyRankUserGrid = Util.GetGameObject(self.gameObject, "RANK/MyRankUser/Grid")
    this.MyRankUserNoRank = Util.GetGameObject(self.gameObject, "RANK/MyRankUser/NoRank")

    --> 奖励
    this.Scroll_2 = Util.GetGameObject(self.gameObject, "REWARD/Scroll")
    this.ScrollPre = Util.GetGameObject(self.gameObject, "REWARD/ScrollPre")
    w = this.Scroll_2.transform.rect.width
    h = this.Scroll_2.transform.rect.height
    this.scrollView_2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll_2.transform, this.ScrollPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 5))
    this.scrollView_2.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView_2.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView_2.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView_2.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView_2.moveTween.MomentumAmount = 1
    this.scrollView_2.moveTween.Strength = 2


    this.itemList = {}
end

--绑定事件（用于子类重写）
function DefenseTrainingRankPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function DefenseTrainingRankPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function DefenseTrainingRankPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function DefenseTrainingRankPopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DefenseTrainingRankPopup:OnShow()
    this.tabCtrl=TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter) 
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)

    _tabIdx = 1
    this.tabCtrl:Init(this.tabBox, _TabData)
    DefenseTrainingRankPopup.ChangeTab(_tabIdx)



    --> mine
    this.MyRankUserGrid:SetActive(false)
    this.MyRankUserNoRank:SetActive(false)
    if DefenseTrainingManager.myRankInfo and DefenseTrainingManager.myRankInfo.rank ~= -1 then
        this.MyRankUserGrid:SetActive(true)

        DefenseTrainingRankPopup:FillMine(this.MyRankUser, DefenseTrainingManager.myRankInfo)
    else
        this.MyRankUserNoRank:SetActive(true)
    end

    this:RefreshScroll_1(1)
    this:RefreshScroll_2(1)
end

function DefenseTrainingRankPopup.OnTabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name

    Util.GetGameObject(tab,"select"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].title)
    Util.GetGameObject(tab,"select/Text"):GetComponent("Text").text = _TabData[index].name

    if status == "select" then
        tabLab:SetActive(false)
        Util.GetGameObject(tab,"select"):SetActive(true)
    else
        tabLab:SetActive(true)
        Util.GetGameObject(tab,"select"):SetActive(false)
    end
end
function DefenseTrainingRankPopup.OnTabIsLockCheck(index)
end
function DefenseTrainingRankPopup.OnChangeTab(index, lastIndex)
    DefenseTrainingRankPopup.ChangeTab(index, 1)
end

function DefenseTrainingRankPopup.ChangeTab(index, scrollIndex)
    _tabIdx = index


    this.RANK:SetActive(false)
    this.REWARD:SetActive(false)
    if _tabIdx == 1 then
        this.RANK:SetActive(true)
    elseif _tabIdx == 2 then
        this.REWARD:SetActive(true)
    end
    -- this:RefreshScroll(scrollIndex)
end

function DefenseTrainingRankPopup:RefreshScroll_1(_index)
    this.scrollView_1:SetData(DefenseTrainingManager.ranks, function(index, root)
        self:FillItem(root, DefenseTrainingManager.ranks[index])
    end)
    if _index then
        this.scrollView_1:SetIndex(_index)
    end
end

function DefenseTrainingRankPopup:FillItem(go, data)
    local headpos = Util.GetGameObject(go, "Grid/User/headBox/headpos")
    local name = Util.GetGameObject(go, "Grid/User/headBox/name"):GetComponent("Text")
    local lv = Util.GetGameObject(go, "Grid/User/headBox/lvFrame/lv"):GetComponent("Text")

    local Stage = Util.GetGameObject(go, "Grid/Stage/Text"):GetComponent("Text")
    local RankImage = Util.GetGameObject(go, "Grid/Rank/Image")
    local RankText = Util.GetGameObject(go, "Grid/Rank/Text")
    local power = Util.GetGameObject(go, "Grid/User/headBox/power"):GetComponent("Text")

    RankImage:SetActive(false)
    RankText:SetActive(false)
    if data.rankInfo.rank <= 3 then
        RankImage:SetActive(true)
        RankImage:GetComponent("Image").sprite = Util.LoadSprite(rankPicArray[data.rankInfo.rank])
    else
        RankText:SetActive(true)
        RankText:GetComponent("Text").text = tostring(data.rankInfo.rank)
    end
    Stage.text = data.rankInfo.param1 or 0

    name.text = data.userName
    lv.text = data.level
    power.text = data.force

    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[go] then
        this.playerHead[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    this.playerHead[go]:Reset()
    this.playerHead[go]:SetHead(data.head)
    this.playerHead[go]:SetFrame(data.headFrame)
    this.playerHead[go]:SetUID(data.uid)
end

function DefenseTrainingRankPopup:FillMine(go, data)
    local headpos = Util.GetGameObject(go, "Grid/User/headBox/headpos")
    local name = Util.GetGameObject(go, "Grid/User/headBox/name"):GetComponent("Text")
    local lv = Util.GetGameObject(go, "Grid/User/headBox/lvFrame/lv"):GetComponent("Text")

    local Stage = Util.GetGameObject(go, "Grid/Stage/Text"):GetComponent("Text")
    local RankImage = Util.GetGameObject(go, "Grid/Rank/Image")
    local RankText = Util.GetGameObject(go, "Grid/Rank/Text")
    local power = Util.GetGameObject(go, "Grid/User/headBox/power"):GetComponent("Text")

    RankImage:SetActive(false)
    RankText:SetActive(false)
    if data.rank <= 3 then
        RankImage:SetActive(true)
        RankImage:GetComponent("Image").sprite = Util.LoadSprite(rankPicArray[data.rank])
    else
        RankText:SetActive(true)
        RankText:GetComponent("Text").text = tostring(data.rank)
    end
    Stage.text = data.param1 or 0
    name.text = PlayerManager.nickName
    lv.text = PlayerManager.level
    power.text = PlayerManager.maxForce

    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[go] then
        this.playerHead[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    this.playerHead[go]:Reset()
    this.playerHead[go]:SetHead(PlayerManager.head)
    this.playerHead[go]:SetFrame(PlayerManager.frame)
    this.playerHead[go]:SetUID(PlayerManager.uid)
end

function DefenseTrainingRankPopup:RefreshScroll_2(scrollIndex)
    local allConfigData = ConfigManager.GetAllConfigsData(ConfigName.DefTrainingRanking)
    table.sort(allConfigData, function(a, b)
        return a.Id < b.Id
    end)
    this.scrollView_2:SetData(allConfigData, function(index, root)
        self:FillItem_2(root, allConfigData[index])
    end)

    if scrollIndex then
        this.scrollView_2:SetIndex(scrollIndex)
    end
end

function DefenseTrainingRankPopup:FillItem_2(go, data)
    local RewardGrid = Util.GetGameObject(go, "RewardGrid")
    local num = Util.GetGameObject(go, "rank/num")
    local Image = Util.GetGameObject(go, "rank/Image")
    num:SetActive(false)
    Image:SetActive(false)

    if this.itemList[go] == nil then
        this.itemList[go] = {}
        for i = 1, 4 do     --< 目前最多支持四个item
            this.itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, RewardGrid.transform)
        end
    end
    
    local itemData = data.RankingAward
    for i = 1, 4 do
        local ItemView = this.itemList[go][i]
        if i <= #itemData then
            ItemView.gameObject:SetActive(true)
            
            ItemView:OnOpen(false, {itemData[i][1], itemData[i][2]}, 0.6, nil, nil, nil, nil, nil)
        else
            ItemView.gameObject:SetActive(false)
        end
    end

    if data.Id <= 3 then
        Image:SetActive(true)
        Image:GetComponent("Image").sprite = Util.LoadSprite(rankPicArray[data.Id])
    else
        num:SetActive(true)
        num:GetComponent("Text").text = data.RankingMin .. "-" .. data.RankingMax
    end
end

--界面关闭时调用（用于子类重写）
function DefenseTrainingRankPopup:OnClose()
    if this.playerHead then
        for _, v in pairs(this.playerHead) do
            v:Recycle()
        end
        this.playerHead = {}
    end
end

--界面销毁时调用（用于子类重写）
function DefenseTrainingRankPopup:OnDestroy()
    this.itemList = {}
end

return DefenseTrainingRankPopup