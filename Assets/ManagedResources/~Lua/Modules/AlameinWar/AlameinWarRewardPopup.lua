require("Base/BasePanel")
AlameinWarRewardPopup = Inherit(BasePanel)
local this = AlameinWarRewardPopup

--初始化组件（用于子类重写）
function AlameinWarRewardPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    -- this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")

    this.scrollRoot = Util.GetGameObject(self.gameObject, "scroll")
    this.Review = Util.GetGameObject(self.gameObject, "Review")
    local w = this.scrollRoot.transform.rect.width
    local h = this.scrollRoot.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform, this.Review, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 25))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.scrollView.elastic = false


    this.repeatItemView = {}
end

--绑定事件（用于子类重写）
function AlameinWarRewardPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    -- Util.AddClick(this.btnClose, function()
    --     self:ClosePanel()
    -- end)

end

--添加事件监听（用于子类重写）
function AlameinWarRewardPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function AlameinWarRewardPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function AlameinWarRewardPopup:OnOpen(...)
    local args = {...}
    this.chapter = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AlameinWarRewardPopup:OnShow()
    this.FreshData()
end

function this.FreshData()
    local starLine = {10, 20, 30}
    this.data = {}
    local chapterConfig = G_AlameinChapter[this.chapter]
    -- 10#300103#1|10#10444#5|20#300101#1|20#6000104#1|30#300102#1|30#300104#1|30#10442#1
    
    
    for i = 1, 3 do
        local line = starLine[i]
        local itemDatas = {}
        for j = 1, #chapterConfig.StarAward do
            if chapterConfig.StarAward[j][1] == line then
                table.insert(itemDatas, {id=chapterConfig.StarAward[j][2], value=chapterConfig.StarAward[j][3]})
            end
        end
        local isGet = 1 --< 0 get 1 noreach 2 alreadyget
        local allStars = AlameinWarManager.GetChapterStars(this.chapter)
        if allStars >= line then
            isGet = 0
            local isFinish = false
            if AlameinWarManager.openedBoxs[this.chapter] and LengthOfTable(AlameinWarManager.openedBoxs[this.chapter]) > 0 then
                for k, v in pairs(AlameinWarManager.openedBoxs[this.chapter]) do
                    if v == i then
                        isFinish = true
                    end
                end
            end
            
            if isFinish then
                isGet = 2
            end
        else
        end

        table.insert(this.data, {isGet = isGet, item = itemDatas, allStars = allStars, idx = i, line = line})
    end

    table.sort(this.data, function(a, b)
        return a.isGet < b.isGet
    end)

    
    

    this.scrollView:SetData(this.data, function(index, root)
        this.SetScrollData(root, this.data[index])
    end)
    this.scrollView:SetIndex(1)
end

function this.SetScrollData(go, data)
    go:SetActive(true)
    local RewardGrid = Util.GetGameObject(go, "Grid/RewardGrid")
    local Title = Util.GetGameObject(go, "Title"):GetComponent("Text")
    local Go = Util.GetGameObject(go, "Go")
    local Text = Util.GetGameObject(go, "Go/Text"):GetComponent("Text")
    local AlreadyGet = Util.GetGameObject(go, "AlreadyGet")
    Go:SetActive(false)
    AlreadyGet:SetActive(false)

    --> item
    if not this.repeatItemView[go] then
        this.repeatItemView[go] = {}
    end

    for k, v in pairs(this.repeatItemView[go]) do
        v.gameObject:SetActive(false)
    end

    for i = 1, #data.item do
        if not this.repeatItemView[go][i] then
            this.repeatItemView[go][i] = SubUIManager.Open(SubUIConfig.ItemView, RewardGrid.transform)
        end
        this.repeatItemView[go][i]:OnOpen(false, {data.item[i].id, data.item[i].value}, 0.55, nil, nil, nil, nil, nil)
        this.repeatItemView[go][i].gameObject:SetActive(true)
    end


    --< 0 get 1 noreach 2 alreadyget
    if data.isGet == 0 then
        Go:SetActive(true)
        Text.text = GetLanguageStrById(22290)
        Go:GetComponent("Image").color = Color.New(255/255,209/255,43/255,255/255)
        Util.AddOnceClick(Go, function()
            NetManager.AlameinBattleBoxGetRequest(this.chapter, data.idx, function(msg)
                AlameinWarManager.RequestMainData(function()
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                        this.FreshData()
                    end)
                end)
            end)
        end)
    elseif data.isGet == 1 then
        Go:SetActive(true)
        Text.text = GetLanguageStrById(10023)
        Go:GetComponent("Image").color = Color.New(255/255,173/255,49/255,255/255)
        Util.AddOnceClick(Go, function()
            UIManager.OpenPanel(UIName.AlameinWarStagePanel, this.chapter)
            this:ClosePanel()
        end)
    elseif data.isGet == 2 then
        AlreadyGet:SetActive(true)
    end
    
    Title.text = string.format(GetLanguageStrById(22552), data.line) .. " <size=30>(" .. GetNumUnenoughColor(data.allStars, data.line) .. ")</size>"
end

--界面关闭时调用（用于子类重写）
function AlameinWarRewardPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function AlameinWarRewardPopup:OnDestroy()
    this.repeatItemView = {}
end

return AlameinWarRewardPopup