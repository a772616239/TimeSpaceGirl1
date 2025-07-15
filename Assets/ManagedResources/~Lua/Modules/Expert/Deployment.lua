local Deployment = quick_class("Deployment")
local this = Deployment
local WordExchangeConfig = ConfigManager.GetConfig(ConfigName.WordExchangeConfig)
local itemsGrid = {}--item重复利用
local itemsGridRight = {}--item重复利用
local limitBuyType={[0]="不限购",[1]="每日限购%s次",[2]="永久限购%s次"}
local items={}--道具预制


function Deployment:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function Deployment:InitComponent(gameObject)
    this.item = Util.GetGameObject(gameObject, "item")
    this.costList = Util.GetGameObject(gameObject, "itemList")

    this.rewardPre = Util.GetGameObject(gameObject, "rewardPre")
    this.rect = Util.GetGameObject(gameObject, "rect")
    local rootHight = this.rect.transform.rect.height
    local width = this.rect.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rect.transform,
            this.rewardPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function Deployment:BindEvent()
end

--添加事件监听（用于子类重写）
function Deployment:AddListener()
end

--移除事件监听（用于子类重写）
function Deployment:RemoveListener()
end

--界面打开时调用（用于子类重写）
function Deployment:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function Deployment:OnShow()
    Deployment:OnShowData()
end
function Deployment:OnSortingOrderChange()

end
function Deployment:OnShowData()
 
    --军备调配数据
    local data=this.InitDynamicActData()
    this.ScrollView:SetData(data, function (index, go)
        this.SingleDataShow(go, data[index])
    end)

    this.costAllList={}
    for i = 1, #this.itemList do
        local costList=ConfigManager.GetConfigData(ConfigName.GlobalActivity,this.itemList[i].activityId)
        for i = 1, #costList.CostItem do
            table.insert(this.costAllList,costList.CostItem[i]) 
        end
    end

    for i = 1, #this.costAllList do
        if items[i] then
            items[i]:SetActive(true)
        else
            local go = newObject(this.item)
            go.transform:SetParent(this.costList.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            items[i]=go
        end

        local showData=this.costAllList[i]
        Util.GetGameObject(items[i],"Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(G_ItemConfig[showData].ResourceID))
        Util.GetGameObject(items[i],"Num"):GetComponent("Text").text=BagManager.GetItemCountById(showData)

    end

    -- local h=this.rect.transform.rect.height
    -- local w=this.rect.transform.rect.width
    -- this.ScrollView:SetScrollRect(Vector2.New(w, h))
  
end


--界面关闭时调用（用于子类重写）
function Deployment:OnClose()

end

--界面销毁时调用（用于子类重写）
function Deployment:OnDestroy()
    items={}
end


function this.InitDynamicActData()
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.Deployment)

    if (not id) or id < 1 then
        return nil
    end    

    local idList={}
    local data= ConfigManager.GetAllConfigsDataByKey("GlobalActivity","Type",ActivityTypeDef.Deployment)
    for i = 1, #data do
        table.insert(idList,data[i].Id)
    end
    this.itemList={}
    for k,v in ipairs(idList) do
        local data=ActivityGiftManager.GetActivityInfoByType(v)
        if data~=nil then
            table.insert(this.itemList,data)
        end
    end

    
    this.allData = {}
    for i = 1, #this.itemList do
        -- local deploymentData=ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.Deployment)
        --军备调配活动Data
        local deploymentData=this.itemList[i]
         for i=1,#deploymentData.mission do 
            local itemData= WordExchangeConfig[deploymentData.mission[i].missionId]           
                local data = {}
                data.id = deploymentData.mission[i].missionId--活动id
                data.actId=deploymentData.activityId
                data.progress = deploymentData.mission[i].progress 
                data.state = deploymentData.mission[i].state
                data.type = ActivityTypeDef.Deployment    --活动状态
                data.reward = {itemData.RewardItem[1][1],itemData.RewardItem[1][2]} 
                data.configData=itemData
                table.insert(this.allData,data)              
        end 

    end
    
    table.sort(this.allData,function (a,b)
        return a.id<b.id
    end)
    return this.allData
end
--刷新每一条的显示数据
function this.SingleDataShow(go, data)
    local contentLeft = Util.GetGameObject(go, "contentLeft/content")
    local contentRight = Util.GetGameObject(go, "contentRight")

    local canBuyNum = Util.GetGameObject(go, "grid/canBuyNum")
    local arleadyBuyNum = Util.GetGameObject(go, "grid/arleadyBuyNum")
    local conversionBtn = Util.GetGameObject(go,"grid/conversionBtn")
   
    --右边数据
    if itemsGrid[go] then
        for i = 1, #itemsGrid[go] do
            itemsGrid[go][i].gameObject:SetActive(false)
        end
        for i = 1, #data.configData.DeductItem do
            local showData=data.configData.DeductItem[i]
            if itemsGrid[go][i] then
                itemsGrid[go][i]:OnOpen(false, {showData[1],showData[2]}, 1,false,false,false)
                itemsGrid[go][i].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[go]={}
        for i = 1, 5 do
            itemsGrid[go][i] = SubUIManager.Open(SubUIConfig.ItemView, contentLeft.transform)
            itemsGrid[go][i].gameObject:SetActive(false)
            local obj= newObjToParent(itemsGrid[go][i].gameObject,itemsGrid[go][i].transform)
            obj.transform:SetAsFirstSibling()
            obj.transform:DOAnchorPos(Vector3(0,-3,0),0)
            obj:GetComponent("RectTransform").transform.localScale=Vector3.one*1.1
            obj.gameObject:SetActive(false)
        end

        for i = 1, #data.configData.DeductItem do
            local showData=data.configData.DeductItem[i]
            if itemsGrid[go][i] then
                itemsGrid[go][i]:OnOpen(false, {showData[1],showData[2]}, 1,false,false,false)
                itemsGrid[go][i].gameObject:SetActive(true)
            end
        end
    end

    --左边数据
    if itemsGridRight[go] then

        itemsGridRight[go]:OnOpen(false, data.reward, 1,false,false,false)
        itemsGridRight[go].gameObject:SetActive(true)
    else

        itemsGridRight[go] = SubUIManager.Open(SubUIConfig.ItemView, contentRight.transform)
        itemsGridRight[go].gameObject:SetActive(true)
        itemsGridRight[go]:OnOpen(false, data.reward, 1,false,false,false)

    end
  

    -- if data.configData.LimitBuyNum==0 then
    --     canBuyNum:SetActive(false)
    --     arleadyBuyNum:SetActive(false)
    -- else
        -- canBuyNum:SetActive(true)
        arleadyBuyNum:SetActive(true)
        if data.configData.LimitBuyType==0 then
           canBuyNum:GetComponent("Text").text=limitBuyType[data.configData.LimitBuyType]
           arleadyBuyNum:SetActive(false)
        else
           canBuyNum:GetComponent("Text").text=string.format( limitBuyType[data.configData.LimitBuyType],data.configData.LimitBuyNum)
           arleadyBuyNum:GetComponent("Text").text=string.format("(%s/%s)",data.progress,data.configData.LimitBuyNum) --已购买次数
        end
    
    -- end
    Util.AddOnceClick(conversionBtn, function()
        --限购次数
        if data.state==1 then
            PopupTipPanel.ShowTip("不可兑换")
            return
        end
      
        for i = 1, #data.configData.DeductItem do
            local showData=data.configData.DeductItem[i]
            if BagManager.GetItemCountById(showData[1])<showData[2] then
                PopupTipPanel.ShowTip("道具集齐不足")
                return
            end
        end

        NetManager.GetActivityRewardRequest(data.id, data.actId, function(drop)
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
            --刷新问题
           Deployment:OnShowData()
        end)
    end)
end


return Deployment