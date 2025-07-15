----- 易经宝库弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local curId = nil--当前已选择的物品的Id
local ActData = {}
local itemList = {}--克隆预制体列表
local goList = {}--勾选按钮列表
local itemIconList = {}--ItemView的List
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local _args
local func

function this:InitComponent(gameObject)
    -- this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "itemPre")
    this.ConfirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.Scroll = Util.GetGameObject(gameObject, "bg/Scroll")

    local rootHight = this.Scroll.transform.rect.height
    local width = this.Scroll.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 2, Vector2.New(10, 5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

function this:BindEvent()
    Util.AddClick(this.ConfirmBtn,function()
        if curId and curId ~= 0 then
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.YiJingBaoKuConfirm,curId,function()
                NetManager.SelectFinalRewardRequest(curId,ActData.activityId,function ()
                    if func then
                        func()
                    end
                    parent:ClosePanel()
                end)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(11796)
        end
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    itemList = {}
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    _args = {...}
    ActData = _args[1]
    func = _args[2]
    -- this.titleText.text = GetLanguageStrById(12426)
    curId = ActData.selectId or nil
    local RewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.BlessingRewardPoolNew,"PoolId",ActData.curFinalPool)
    this.ScrollView:SetData(RewardConfig, function(index, go)
        this:SetSingleData(index, go, RewardConfig[index])
    end)
end

function this:SetSingleData(index, item, data)
    item:SetActive(true)
    -- itemList[index] = item
    local icon = Util.GetGameObject(item,"icon")
    local name = Util.GetGameObject(item,"name"):GetComponent("Text")
    local num = Util.GetGameObject(item,"num"):GetComponent("Text")
    local limit1 = Util.GetGameObject(item,"limit1"):GetComponent("Text")
    local limit2Bg = Util.GetGameObject(item,"bg")
    local limit2 = Util.GetGameObject(item,"limit2"):GetComponent("Text")
    local select = Util.GetGameObject(item,"select")
    local go = Util.GetGameObject(item,"select/Go")
    
    goList[index] = go

    item:SetActive(true)
    if not itemIconList[item] then
        local view = SubUIManager.Open(SubUIConfig.ItemView, icon.transform)
        itemIconList[item] = view
    end
    itemIconList[item]:OnOpen(false,data.Reward,0.65,false)
    name.text = GetLanguageStrById(itemConfig[data.Reward[1]].Name)

    --判断是否选了该物品
    if curId == data.Id then
        go:SetActive(true)
    else
        go:SetActive(false)
    end
    --选择一个物品
    Util.AddOnceClick(select,function()
        if go.gameObject.activeSelf then
            go:SetActive(false)
            curId = nil
        else
            for index, value in ipairs(goList) do
                goList[index]:SetActive(false)
            end
            go:SetActive(true)
            curId = data.Id
        end
    end)

    local t1 = true
    local t2 = true
    local t3 = true
    --判断是否可以选择
    if PlayerManager.level >= data.LevelLimit then
        num.gameObject:SetActive(true)
        limit1.gameObject:SetActive(false)
        select:SetActive(true)
    else
        limit1.gameObject:SetActive(true)
        limit1.text = string.format(GetLanguageStrById(12427), data.LevelLimit)
        t1 = false
    end

    if ActData.curLevel >= data.FloorLimit then
        num.gameObject:SetActive(true)
        limit2.gameObject:SetActive(false)
        limit2Bg.gameObject:SetActive(false)
        select:SetActive(true)
    else
        limit2.gameObject:SetActive(true)
        limit2Bg.gameObject:SetActive(true)
        limit2.text = data.FloorLimit .. GetLanguageStrById(12428)
        t2 = false
    end

    local progress
    for index, value in ipairs(ActData.allData) do
        if value.configId == data.Id then
            progress = value.progress
        end
    end
    
    if progress > data.InitializeNum then
        t3 = false
    elseif progress == data.InitializeNum and ActData.curLevel > data.InitializeNum then
        t3 = false
        num.text = string.format("( <color=red>%s</color> / %s )", data.InitializeNum-progress, data.InitializeNum)
        -- num.text = "(<color=red>"..(data.InitializeNum-ActData.allData[index].progress).."/"..data.InitializeNum.."</color>)"
    else
        t3 = true
        num.text = string.format("( %s / %s )", data.InitializeNum-progress, data.InitializeNum)
    end

    num.gameObject:SetActive(t1 and t2)
    select:SetActive(t1 and t2 and t3)

end

function this:OnClose()

end

function this:OnDestroy()
    itemIconList = {}
end

return this