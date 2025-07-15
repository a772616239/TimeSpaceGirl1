require("Base/BasePanel")
local ATMTeamRankPopup = Inherit(BasePanel)
local this = ATMTeamRankPopup
local _PlayerHeadList = {}
--初始化组件（用于子类重写）
function ATMTeamRankPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.title = Util.GetGameObject(self.transform, "Title"):GetComponent("Text")
    this.commonPanel = Util.GetGameObject(self.transform, "content/Common")
    this.rankPanel = Util.GetGameObject(self.transform, "content/Rank")
    this.emptyPanel = Util.GetGameObject(self.transform, "content/Empty")
    this.emptyText = Util.GetGameObject(self.transform, "content/Empty/Image/Text"):GetComponent("Text")
    this.scrollRoot = Util.GetGameObject(self.transform, "content/Rank/scrollpos")
    this.recordPre = Util.GetGameObject(this.scrollRoot, "mem")

    local rootWidth = this.scrollRoot.transform.rect.width
    local rootHeight = this.scrollRoot.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
            this.recordPre, nil, Vector2.New(rootWidth, rootHeight), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function ATMTeamRankPopup:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ATMTeamRankPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ATMTeamRankPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ATMTeamRankPopup:OnOpen(...)
    -- 请求数据
    local dataList = ArenaTopMatchManager.GetMyTeamRankInfo()
    if #dataList == 0 then
        this.emptyPanel:SetActive(true)
        this.rankPanel:SetActive(false)
        this.emptyText.text = GetLanguageStrById(10137)
    else
        this.emptyPanel:SetActive(false)
        this.rankPanel:SetActive(true)
        -- 设置数据
        this.ScrollView:SetData(dataList, function(index, go)
            this.RefreshData(go, dataList[index])
        end)
    end
    this.title.text = GetLanguageStrById(10138)
    this.commonPanel:SetActive(false)
end

function this.RefreshData(go, data)
    --- 基础信息
    local head = Util.GetGameObject(go, "head")
    local rankBg = Util.GetGameObject(go, "rank")
    local rankLab = Util.GetGameObject(rankBg, "num")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local force = Util.GetGameObject(go, "force"):GetComponent("Text")
    local score = Util.GetGameObject(go, "score"):GetComponent("Text")

    local personInfo = data.personInfo
    Util.GetGameObject(go,"bg/selfBg"):SetActive(personInfo.uid == PlayerManager.uid)
    -- 排名
    if personInfo.rank > 0 and personInfo.rank <= 2 then
        rankBg:GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_0"..personInfo.rank)
        rankBg:GetComponent("Image"):SetNativeSize()
        rankLab:SetActive(false)
    else
        rankBg:GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rankBg:GetComponent("RectTransform").sizeDelta = Vector2.New(120, 120)
        rankLab:GetComponent("Text").text = personInfo.rank <= 0 and "200+" or personInfo.rank
        rankLab:SetActive(true)
    end
    -- 基础信息
    name.text = personInfo.name
    force.text = personInfo.totalForce
    local deltaIntegral = ArenaTopMatchManager.GetMatchDeltaIntegral()
    score.text = personInfo.score * deltaIntegral --> 0 and personInfo.score * deltaIntegral or GetLanguageStrById(12207)

    if not _PlayerHeadList[go] then
        _PlayerHeadList[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[go]:Reset()
    _PlayerHeadList[go]:SetScale(Vector3.one * 0.7)
    _PlayerHeadList[go]:SetHead(personInfo.head)
    _PlayerHeadList[go]:SetFrame(personInfo.headFrame)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ATMTeamRankPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function ATMTeamRankPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function ATMTeamRankPopup:OnDestroy()
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    this.ScrollView = nil
end

return ATMTeamRankPopup