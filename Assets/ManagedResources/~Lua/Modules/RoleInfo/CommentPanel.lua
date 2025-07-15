require("Base/BasePanel")
CommentPanel = Inherit(BasePanel)
local this = CommentPanel
local heroData

--评论切换
local switchBtnTxt = {
    GetLanguageStrById(50160),
    GetLanguageStrById(50161),
}
local listType = 0 --0热门 1最新

--初始化组件（用于子类重写）
function CommentPanel:InitComponent()
    this.frame = Util.GetGameObject(self.gameObject, "bg/frame"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.gameObject, "bg/icon"):GetComponent("Image")
    this.name = Util.GetGameObject(self.gameObject, "bg/name"):GetComponent("Text")
    this.commentValue = Util.GetGameObject(self.gameObject, "bg/comment/Text"):GetComponent("Text")
    this.thumbsUpValue = Util.GetGameObject(self.gameObject, "bg/thumbsUp/Text"):GetComponent("Text")
    this.CommentBtn = Util.GetGameObject(self.gameObject, "bg/CommentBtn")
    this.switchBtn = Util.GetGameObject(self.gameObject, "bg/switchBtn")
    this.scroll = Util.GetGameObject(self.gameObject, "bg/scroll")
    this.prefab = Util.GetGameObject(self.gameObject, "bg/prefab")
    this.myComment = Util.GetGameObject(self.gameObject, "bg/myComment")
    this.backBtn = Util.GetGameObject(self.gameObject, "bg/backBtn")

    local v2 = this.scroll:GetComponent("RectTransform").rect
    this.CommentScrollCycle = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(0,0))
end

--绑定事件（用于子类重写）
function CommentPanel:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function CommentPanel:AddListener()
end

--移除事件监听（用于子类重写）
function CommentPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function CommentPanel:OnOpen(data)
    heroData = data
end

function CommentPanel:OnShow()
    NetManager.RequestEvaluateTank(heroData.Id, 1, 1,function (msg)
        this:CommentPanelShow(msg)
    end)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    local grid = Util.GetGameObject(this.CommentScrollCycle.gameObject, "grid")
    for i = 1, grid.transform.childCount do
        grid.transform:GetChild(i - 1).gameObject:SetActive(false)
    end
    Util.GetGameObject(this.myComment, "InputField"):GetComponent("InputField").text = ""
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

local haveHero = false
--显示评论窗口
function this:CommentPanelShow(data)
    listType = 0
    this.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(heroData.Quality,heroData.star))
    this.icon.sprite = Util.LoadSprite(GetResourcePath(heroData.Icon))
    this.name.text = GetLanguageStrById(heroData.ReadingName)
    haveHero = PlayerManager.GetHeroDataByStar(heroData.Star,heroData.Id)
    this:RefreshScrollCycle(data)

    Util.AddOnceClick(this.CommentBtn, function ()
        NetManager.RequestEvaluateTankLike(heroData.Id, function ()
            NetManager.RequestEvaluateTank(heroData.Id, 1, 1, function (msg)
                this:RefreshScrollCycle(msg)
            end)
        end)
    end)
    Util.AddOnceClick(this.switchBtn, function ()
        NetManager.RequestEvaluateTank(heroData.Id, 1, 1, function (msg)
            if listType == 0 then
                listType = 1
            else
                listType = 0
            end
            this:RefreshScrollCycle(msg)
        end)
    end)
end

--刷新列表
function this:RefreshScrollCycle(msg)
    local data = msg
    this.commentValue.text = data.commentNum
    this.thumbsUpValue.text = data.loveDegree
    Util.GetGameObject(this.switchBtn, "Text"):GetComponent("Text").text = switchBtnTxt[listType+1]
    -- Util.SetGray(this.CommentBtn, data.isLikedHero)
    if data.isLikedHero then
        this.CommentBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jingjichang_yizan"))
    else
        this.CommentBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jingjichang_dianzan"))
    end

    local highLikesList = {}
    for index, value in ipairs(data.heroCommentList) do
        table.insert(highLikesList, value)
    end
    if listType == 0 then
        highLikesList = this.SortData(highLikesList)
    else
        highLikesList = this.SortDataLike(highLikesList)
    end

    this.CommentScrollCycle:SetData(highLikesList, function(index, go)
        this:SetScrollCycle(go, highLikesList[index])
    end)
    NetManager.HeroMyCommentRequest(heroData.Id,function (msg)
        this:MyComment(msg)
    end)

end

--热门排序
function this.SortData(allData)
    if allData == nil then
        return
    end
    table.sort(allData, function(a,b)
        if a.time == b.time then
            return a.likes < b.likes
        else
            return a.time < b.time
        end
    end)
    return allData
end

--最新排序
function this.SortDataLike(allData)
    if allData == nil then
        return
    end
    table.sort(allData, function(a,b)
        if a.likes == b.likes then
            return a.time < b.time
        else
            return a.likes < b. likes
        end
    end)
    return allData
end

--设置列表信息
function this:SetScrollCycle(_go, _itemData)
    _go:SetActive(true)
    Util.GetGameObject(_go, "playerName"):GetComponent("Text").text = _itemData.uName
    Util.GetGameObject(_go, "comment"):GetComponent("Text").text = _itemData.content
    Util.GetGameObject(_go, "thumbsUp/Text"):GetComponent("Text").text = _itemData.likes
    local commentBtn = Util.GetGameObject(_go,"CommentBtn")
    -- Util.SetGray(commentBtn, _itemData.isLikedIt)

    if _itemData.isLikedIt then
        commentBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jingjichang_yizan"))
    else
        commentBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jingjichang_dianzan"))
    end

    Util.AddOnceClick(commentBtn, function()
        NetManager.RequestEvaluateTankId(_itemData.id, function ()
            NetManager.RequestEvaluateTank(heroData.Id, 1, 1,function (msg)
                this:RefreshScrollCycle(msg)
            end)
        end)
    end)
end

--我的评论
function this:MyComment(msg)
    local comment = Util.GetGameObject(this.myComment, "comment")
    local thumbsUpValue = Util.GetGameObject(this.myComment, "thumbsUp/Text"):GetComponent("Text")
    local delectBtn = Util.GetGameObject(this.myComment, "delectBtn")
    local sendOutBtn = Util.GetGameObject(this.myComment, "sendOutBtn")
    local inputField = Util.GetGameObject(this.myComment, "InputField")

    if haveHero then
        if msg.myComment.content == "" then
            inputField:SetActive(true)
            comment:SetActive(false)
            thumbsUpValue.text = 0
            delectBtn:SetActive(false)
            sendOutBtn:SetActive(true)

            Util.AddOnceClick(sendOutBtn, function()
                local sendTxt = inputField:GetComponent("InputField").text
                if sendTxt == "" then
                    return
                end
                NetManager.RequestEvaluateTankText(heroData.Id, sendTxt, function ()
                    NetManager.RequestEvaluateTank(heroData.Id, 1, 1,function (msg)
                        this:RefreshScrollCycle(msg)
                    end)
                end)
            end)
        else
            inputField:SetActive(false)
            comment:SetActive(true)
            comment:GetComponent("Text").text = msg.myComment.content
            thumbsUpValue.text = msg.myComment.likes
            delectBtn:SetActive(true)
            sendOutBtn:SetActive(false)

            Util.AddOnceClick(delectBtn, function()
                NetManager.RequestEvaluateTankDelText(heroData.Id, msg.myComment.id,function ()
                    NetManager.RequestEvaluateTank(heroData.Id, 1, 1,function (msg)
                        this:RefreshScrollCycle(msg)
                    end)
                end)
            end)
        end
    else
        inputField:SetActive(true)
        comment:SetActive(false)
        thumbsUpValue.text = 0
        Util.AddOnceClick(sendOutBtn, function()
            PopupTipPanel.ShowTip(GetLanguageStrById(50222))
        end)
    end
end

return CommentPanel