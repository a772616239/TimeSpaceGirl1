require("Base/BasePanel")
ClimbTowerRankPopup = Inherit(BasePanel)
local this = ClimbTowerRankPopup

--初始化组件（用于子类重写）
function ClimbTowerRankPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")

    this.scrollParentView = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView")
    this.itemPre = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView/ItemPre")
    local v21 = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView"):GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollParentView.transform,this.itemPre,
            nil,Vector2.New(-v21.x*2, -v21.y*2),1,1,Vector2.New(0,8)) 
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    --没有排行信息
    this.noneImage = Util.GetGameObject(self.gameObject,"RankList/NoneImage")
    --自己的排名信息
    this.record = Util.GetGameObject(self.gameObject,"RankList/Record")
end

--绑定事件（用于子类重写）
function ClimbTowerRankPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ClimbTowerRankPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ClimbTowerRankPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ClimbTowerRankPopup:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerRankPopup:OnShow()
    --设置自己的排行数据
    this.SetRankingMyItemInfo(this.record,ClimbTowerManager.serverRankData.myRankInfo)

    this.rankDatas = ClimbTowerManager.GetSortRanks()
    this:RefreshScroll(1)

    this.noneImage:SetActive(false)
    if #this.rankDatas <= 0 then
        this.noneImage:SetActive(true)
    end
end

function ClimbTowerRankPopup:RefreshScroll(index)
    this.scrollView:SetData(this.rankDatas, function(index, root)
        this.SetRankingItemInfo(root, self.rankDatas[index])
    end)
    if index then
        this.scrollView:SetIndex(index)
    end
end

function this.SetRankingItemInfo(root,data)
    this.SetRankingInfo(root,data.rankInfo,data.userName,data.head,data.headFrame,data.level)

    --底板颜色根据排名更改
    local spriteName
    local colorValue

    if data.rankInfo.rank == 1 then
        spriteName = "cn2-X1_tongyong_liebiao_02"
        colorValue = Color.New(1, 0.7764706, 0.1568628, 1)
    elseif data.rankInfo.rank == 2 then
        spriteName = "cn2-X1_tongyong_liebiao_03"
        colorValue = Color.New(1, 0.6627451, 0.3607843, 1)
    elseif data.rankInfo.rank ==3 then
        spriteName = "cn2-X1_tongyong_liebiao_04"
        colorValue = Color.New(1, 0.6117647, 0.5803922, 1)
    else
        spriteName = "cn2-X1_tongyong_liebiao_05"
        colorValue = Color.New(0.7803922,0.5529412, 0.9960784, 1)
    end

    local Image_BG1 = Util.GetGameObject(root, "BG/Image_BG1"):GetComponent("Image")
    local Image_BG2 = Util.GetGameObject(root, "BG/Image_BG2"):GetComponent("Image")

    Image_BG1.sprite = Util.LoadSprite(spriteName)
    Image_BG2.color = colorValue

    local clickBtn = Util.GetGameObject(root,"ClickBtn")
    Util.AddOnceClick(clickBtn,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
    end)

end

function this.SetRankingMyItemInfo(root,data)
    this.SetRankingInfo(root,data,PlayerManager.nickName,PlayerManager.head,PlayerManager.frame,PlayerManager.level)
end

--设置排名逻辑
function this.SetRankingInfo(root, data, playerName, playerHead, playerFrame, PlayerLevel)
    local integral = Util.GetGameObject(root,"integral"):GetComponent("Text")
    local _integral = data.param1 or 0
    if _integral < 0 then _integral = 0 end
    integral.text = _integral
    --玩家信息
    local headpos = Util.GetGameObject(root,"Head")
    local name = Util.GetGameObject(root,"name"):GetComponent("Text")
    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[root] then
        this.playerHead[root] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    this.playerHead[root]:SetScale(Vector3.one * 0.5)
    name.text = playerName
    this.playerHead[root]:SetHead(playerHead)
    this.playerHead[root]:SetFrame(playerFrame)
    this.playerHead[root]:SetLevel(PlayerLevel)
    --排名
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] = Util.GetGameObject(root,"SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end

    if data.rank <= 0 then
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = GetLanguageStrById(10041)
    elseif  data.rank > 3  then
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = data.rank
    else
        sortNumTabs[data.rank]:SetActive(true)
    end
end

--界面关闭时调用（用于子类重写）
function ClimbTowerRankPopup:OnClose()
    if this.playerHead then
        for _, v in pairs(this.playerHead) do
            v:Recycle()
        end
        this.playerHead = {}
    end
end

--界面销毁时调用（用于子类重写）
function ClimbTowerRankPopup:OnDestroy()

end

return ClimbTowerRankPopup