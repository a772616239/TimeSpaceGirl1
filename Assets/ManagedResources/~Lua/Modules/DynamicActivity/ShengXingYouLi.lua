local ShengXingYouLi = quick_class("ShengXingYouLi")
local actData={}
local itemsGrid = {}--item重复利用
local this=ShengXingYouLi
local parent
local activityId
function ShengXingYouLi:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function ShengXingYouLi:InitComponent(gameObject)
    this.time = Util.GetGameObject(gameObject, "tiao/time"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "ItemPre3")
    this.scrollItem = Util.GetGameObject(gameObject, "scrollItem")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function ShengXingYouLi:BindEvent()
end

--添加事件监听（用于子类重写）
function ShengXingYouLi:AddListener()
end

--移除事件监听（用于子类重写）
function ShengXingYouLi:RemoveListener()
end
local sortingOrder = 0
--界面打开时调用（用于子类重写）
function ShengXingYouLi:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ShengXingYouLi:OnShow(_sortingOrder,_parent)
    parent = _parent
    sortingOrder = _sortingOrder
    this:OnShowData(true,true)
    this:SetTime()
end
function ShengXingYouLi:OnShowData(isTop,isAni)
    actData={}
    actData = DynamicActivityManager.ShengXingYouLiGetData()
    activityId = actData.activityId
    if actData.mission then
        this.SortData(actData.mission)
        actData.mission[#actData.mission+1] = {}
        this.ScrollView:SetData(actData.mission, function (index, go)
            if index == #actData.mission then
                go:SetActive(false)
                return
            end
            go:SetActive(true)
            this.SingleDataShow(go, actData.mission[index])
        end,not isTop,not isAni)
    end
    
end



--刷新每一条的显示数据
function this.SingleDataShow(pre,value)
    if pre==nil or value==nil then
        return
    end
    --绑定组件
    local sData = value
    local btnText = Util.GetGameObject(pre, "btnGet/btn"):GetComponent("Text")
    local btnGet = Util.GetGameObject(pre, "btnGet")
    local btnGo = Util.GetGameObject(pre, "btnGo")
    local grid = Util.GetGameObject(pre, "scrollView/grid")
    local shadow = Util.GetGameObject(pre, "shadow")
    local finishImg = Util.GetGameObject(pre, "finish")
    local redPot = Util.GetGameObject(pre, "btnGet/redPoint")
    local text = Util.GetGameObject(pre, "titleImage/titleText"):GetComponent("Text")

    local canDo = 0
    if sData.progress >= sData.need then
        if sData.state == 0 then
            canDo = 1
        else
            canDo = 2
        end
    end
    btnGo:SetActive(canDo == 0)
    btnGet:SetActive(canDo == 1)
    redPot:SetActive(canDo == 1)
    finishImg:SetActive(canDo == 2)
    text.text = sData.word

    local shows = sData.reward
    --滚动条复用重设itemview
    if itemsGrid[pre] then
        for i = 1, 4 do
            itemsGrid[pre][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if itemsGrid[pre][i] then
                itemsGrid[pre][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
                itemsGrid[pre][i].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[pre]={}
        for i = 1, 4 do
            itemsGrid[pre][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            itemsGrid[pre][i].gameObject:SetActive(false)
            local obj= newObjToParent(shadow,itemsGrid[pre][i].transform)
            obj.transform:SetAsFirstSibling()
            obj.transform:DOAnchorPos(Vector3(0,-3,0),0)
            obj:GetComponent("RectTransform").transform.localScale=Vector3.one*1.1
            obj.gameObject:SetActive(true)
        end
        for i = 1, #shows do
            itemsGrid[pre][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
            itemsGrid[pre][i].gameObject:SetActive(true)
        end
    end

    Util.AddOnceClick(btnGet,function ()
        if canDo == 1 then
            NetManager.GetActivityRewardRequest(sData.missionId,activityId,function (drop)
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1,function ()
                    this:OnShowData(false,false)
                    CheckRedPointStatus(RedPointType.ShengXingYouLi)
                end)
            end)
        end
    end)

    Util.AddOnceClick(btnGo,function ()
        JumpManager.GoJump(sData.jump)
    end)

end

function this.SortData(tempData)
    if tempData==nil then
        return
    end
    table.sort(tempData, function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return a.state < b.state
        end
    end)
end

function ShengXingYouLi:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local endTime = actData.endTime--ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.DynamicAct_Treasure)
    local timeDown = endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(10470)..TimeToDHMS(timeDown)
    self.timer = Timer.New(function()
        this.time.text = GetLanguageStrById(10470)..TimeToDHMS(timeDown)
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            parent:ClosePanel()
            return
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    self.timer:Start()
end

function ShengXingYouLi:OnClose()

end

--界面销毁时调用（用于子类重写）
function ShengXingYouLi:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

function ShengXingYouLi:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

return ShengXingYouLi