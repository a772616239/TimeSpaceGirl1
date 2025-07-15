require("Modules.Battle.Config.PokemonEffectConfig")
require("Base/BasePanel")
SecretBoxPanel = Inherit(BasePanel)
local this=SecretBoxPanel
local AllActSetConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
-- Tab管理器
--local TabBox = require("Modules/Common/TabBox")
--local _TabData = {
--    [1]= {
--        default = "r_playerrumble_shanganniudi_02", select = "r_playerrumble_shanganniudi_01",
--        img_default = "r_mihe_xiangqing_01",img_select = "r_mihe_xiangqing_02",
--    },
--    [2]= {
--        default = "r_playerrumble_shanganniudi_02", select = "r_playerrumble_shanganniudi_01",
--        img_default = "r_playerrumble_shangdainzi_02",img_select = "r_playerrumble_shangdainzi_01",
--    }
--}
local orginLayer = 0

local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
--示意图轮回放
local imageList = {}
local viewList = {}
local year
local month
local day
local year1
local month1
local day1
local STARTTIME = 1
local ENDTIME = 2
local canDrag = true
local i = 1
local shop_btnBack

--初始化组件（用于子类重写）
function SecretBoxPanel:InitComponent()

    screenAdapte(Util.GetGameObject(self.gameObject, "bgImage"))
    poolManager:LoadLive("live2d_mihe", Util.GetTransform(self.gameObject, "bgImage"), Vector3.one, Vector3.New(0, 69, 0))--127

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.btnShop = Util.GetGameObject(self.gameObject,"btnShop")
    this.contentRoot = Util.GetGameObject(self.gameObject, "content")
    this.detailPanel = Util.GetGameObject(self.gameObject, "content/detail")
    this.helpBtn = Util.GetGameObject(self.gameObject,"content/detail/helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.itemContent1 = Util.GetGameObject(this.detailPanel, "left/mainItem/content/content1")
    this.itemContent2 = Util.GetGameObject(this.detailPanel, "left/mainItem/content/content2")
    this.content = Util.GetGameObject(this.detailPanel, "left/mainItem/content")
    this.itemName1 = Util.GetGameObject(this.detailPanel, "left/mainItem/content/content1/itemName1"):GetComponent("Text")
    this.itemName2 = Util.GetGameObject(this.detailPanel, "left/mainItem/content/content2/itemName2"):GetComponent("Text")
    this.headBtn = Util.GetGameObject(this.detailPanel, "left/mainItem/headBG")
    this.headImage = Util.GetGameObject(this.detailPanel, "left/mainItem/headBG/headImage"):GetComponent("Image")
    this.activityTimeText = Util.GetGameObject(this.detailPanel, "left/activityTimeText"):GetComponent("Text")
    this.openNumberAgainText = Util.GetGameObject(this.detailPanel, "right/needOpenNumberDetailText1 (1)"):GetComponent("Text")
    this.buyOneBtn = Util.GetGameObject(this.detailPanel, "bottom/openOneButton")
    this.buyTenBtn = Util.GetGameObject(this.detailPanel, "bottom/openOneButton (1)")
    this.content1 = Util.GetGameObject(this.detailPanel, "bottom/openOneButton/content1")
    this.content2 = Util.GetGameObject(this.detailPanel, "bottom/openOneButton/content2")
    this.costImage1 = Util.GetGameObject(this.detailPanel, "bottom/openOneButton/content1/Image")
    this.costImage2 = Util.GetGameObject(this.detailPanel, "bottom/openOneButton (1)/Image")
    --this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    self.imageList = { "y_yuansu_yuansu", "y_yuansu_qunying", "y_yuansu_mihe","y_yuansu_yuansu", "y_yuansu_qunying", "y_yuansu_mihe" }
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    local itemdata = {}
    table.insert(itemdata,SecretBoxManager.StarDifferDemonsId[1])
    table.insert(itemdata,0)
    local view = SubUIManager.Open(SubUIConfig.ItemView,this.itemContent1.transform)
    viewList[1] = view
    view:OnOpen(false,itemdata,0.8,false,false,false,self.sortingOrder)
    local itemdata = {}
    table.insert(itemdata,SecretBoxManager.StarDifferDemonsId[2])
    table.insert(itemdata,0)
    local view2 = SubUIManager.Open(SubUIConfig.ItemView,this.itemContent2.transform)
    viewList[2] = view2
    view2:OnOpen(false,itemdata,0.8,false,false,false,self.sortingOrder)
    this:ShowImage(1)
    this.activityTimeText.text = SecretBoxManager.SeasonOpen.."-"..SecretBoxManager.SeasonEnd
    this.canGetRewardNumber = SecretBoxManager.ShowTime-SecretBoxManager.count%SecretBoxManager.ShowTime
    this.costImage1:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[SecretBoxManager.MainCost[1][1][1]].ResourceID))
    this.costImage2:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[SecretBoxManager.MainCost[2][1][1]].ResourceID))
    this.openNumberAgainText.text = this.canGetRewardNumber
    --this.secretBoxRed1Point = Util.GetGameObject(self.transform, "scrollRect/secretBoxRed1Point")
    this.secretBoxRed2Point = Util.GetGameObject(self.transform, "content/detail/bottom/openOneButton/content2/secretBoxRed2Point")
    --this.recruitRedPoint = Util.GetGameObject(self.transform, "scrollRect/secretBoxRed1Point (1)")
    SecretBoxManager.count = SecretBoxManager.ShowTime-this.canGetRewardNumber
end

function SecretBoxPanel:OnRefresh()
    this.openNumberAgainText.text=SecretBoxManager.ShowTime-SecretBoxManager.count
end


function SecretBoxPanel:ShowImage(index)
    if index + 1 > 3 then
        index = 0
    end
    this.itemName1.text = ItemConfig[SecretBoxManager.StarDifferDemonsId[index+1]].Name
    viewList[1].frame:GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(ItemConfig[SecretBoxManager.StarDifferDemonsId[index+1]].Quantity))
    local itemdata={}
    table.insert(itemdata,SecretBoxManager.StarDifferDemonsId[index+1])
    table.insert(itemdata,0)
    viewList[1]:NoGetRewardShow(itemdata,0)
    viewList[1].gameObject:GetComponent("RectTransform").localScale  = Vector2.New(0.8, 0.8)
    this.itemContent1.transform:DOAnchorPosX(this.itemContent1.transform.anchoredPosition.x, 2, false)
        :SetEase(Ease.Linear):SetDelay(3):OnComplete(function()
        viewList[1].icon:GetComponent("Image"):DOFade(0, 0.2):OnComplete(function ()
            viewList[1].icon:GetComponent("Image"):DOFade(1, 0.2)
            this:ShowImage(index + 1)
        end)
    end)

    local diffId = DiffMonsterManager.GetDiffMonsterByComponentId(itemdata[1])
    this.headImage.sprite = Util.LoadSprite(PokemonEffectConfig[diffId].icon)
end
function SecretBoxPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(Util.GetGameObject(self.gameObject, "bgImage"), self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.contentRoot, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

--绑定事件（用于子类重写）
function SecretBoxPanel:BindEvent()
     --初始化Tab管理器
    --this.TabCtrl = TabBox.New()
    --this.TabCtrl:SetTabAdapter(this.TabAdapter)
    --this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    --this.TabCtrl:Init(this.tabbox, _TabData)

    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
        --UIManager.OpenPanel(UIName.MainPanel)
    end)
    --商店按钮
    Util.AddClick(this.btnShop, function ()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.SECRET_BOX_SHOP)
    end)
    --
    --Util.AddClick(shop_btnBack,function()
    --    this.scrollRect:SetActive(true)
    --        this.detailPanel:SetActive(true)
    --        this.btnBack:SetActive(true)
    --        this.btnShop:SetActive(true)
    --        shop_btnBack:SetActive(false)
    --        -- 关闭商店界面
    --        if this.shopView then
    --            this.shopView = SubUIManager.Close(this.shopView)
    --            this.shopView = nil
    --            this:RefreshRedPointShow()
    --        end
    --        -- 货币界面
    --        this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.SecretBox })
    --end)
    -- 帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.SecretBoxRecruit,this.helpPosition.x,this.helpPosition.y)
    end)

    Util.AddClick(this.buyOneBtn, function ()
        if(SecretBoxManager.secretBoxFreeUseTime<1) then
            if PopQuickPurchasePanel(UpViewRechargeType.GhostRing, 1) then
                return
            end
        end
        if((BagManager.GetItemCountById(SecretBoxManager.MainCost[2][1][1])+SecretBoxManager.secretBoxFreeUseTime) >= 1) then
            if(SecretBoxManager.SeasonTime > 1) then
                SecretBoxManager.GetSecretBoxRewardRequest(SecretBoxManager.typeId[2*SecretBoxManager.SeasonTime-1],1)
            end
        end
    end)
    Util.AddClick(this.buyTenBtn, function ()
        if PopQuickPurchasePanel(UpViewRechargeType.GhostRing, 10) then
            return
        end
        if((BagManager.GetItemCountById(SecretBoxManager.MainCost[2][1][1])) >= 10) then
            if(SecretBoxManager.SeasonTime > 1) then
                SecretBoxManager.GetSecretBoxRewardRequest(SecretBoxManager.typeId[2*SecretBoxManager.SeasonTime],10)
            end
        end
    end)
    --主打异妖头像按钮
    Util.AddClick(this.headBtn,function()
        UIManager.OpenPanel(UIName.DiffMonsterPreviewSecretBoxPanel)
    end)
    --BindRedPointObject(RedPointType.SecretBox_Red1,this.secretBoxRed1Point)
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "Image")
    img:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index]["img_"..status])
end

-- tab改变回调事件
--function this.OnTabChange(index, lastIndex)
--    -- 商店界面特殊处理
--    if index == 1 then
--        this.scrollRect:SetActive(true)
--        this.detailPanel:SetActive(true)
--        -- 关闭商店界面
--        if this.shopView then
--            this.shopView.gameObject:SetActive(false)
--            this:RefreshRedPointShow()
--        end
--        -- 货币界面
--        this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.SecretBox })
--
--    elseif index == 2 then
--        this.scrollRect:SetActive(false)
--        this.detailPanel:SetActive(false)
--        if not this.shopView then
--            this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.contentRoot.transform)
--        end
--        this.shopView.gameObject:SetActive(true)
--        this.secretBoxRed2Point:SetActive(false)
--        this.shopView:ShowShop(SHOP_TYPE.SECRET_BOX_SHOP)
--        -- 货币界面
--
--        this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.SecretBoxShop })
--
--    end
--end


function SecretBoxPanel.OpenOneRewardPanel(drop)
    this:OnRefresh()
    UIManager.OpenPanel(UIName.SecretBoxBuyOnePanel,drop)
end
function SecretBoxPanel.OpenTenRewardPanel(drop)
    this:OnRefresh()
    UIManager.OpenPanel(UIName.SecretBoxBuyTenPanel,drop)
end
function SecretBoxPanel:TimeFormation(time,index)
    if(STARTTIME==index) then
        year=string.sub(time,1,4)
        month=string.sub(time,5,6)
        day=string.sub(time,7,8)
    end
    if(ENDTIME==index) then
        year1=string.sub(time,1,4)
        month1=string.sub(time,5,6)
        day1=string.sub(time,7,8)
    end
end

-- 刷新红点显示
function  SecretBoxPanel:RefreshRedPointShow()
    if(SecretBoxManager.secretBoxFreeUseTime<1 or not ActTimeCtrlManager.SingleFuncState(21)) then
        this.content1:SetActive(true)
        this.content2:SetActive(false)
    else
        this.content1:SetActive(false)
        this.content2:SetActive(true)
    end
    if(viewList[1]) then
        local itemdata={}
        table.insert(itemdata,SecretBoxManager.StarDifferDemonsId[1])
        table.insert(itemdata,0)
        viewList[1]:OnOpen(false,itemdata,0.8,false,false,false,self.sortingOrder)
        local itemdata = {}
        table.insert(itemdata,SecretBoxManager.StarDifferDemonsId[2])
        table.insert(itemdata,0)
        viewList[2]:OnOpen(false,itemdata,0.8,false,false,false,self.sortingOrder)
        this:ShowImage(1)
        this:TimeFormation(SecretBoxManager.SeasonOpen,STARTTIME)
        this:TimeFormation(SecretBoxManager.SeasonEnd,ENDTIME)
        this.activityTimeText.text=year.."."..month.."."..day.."-"..year1.."."..month1.."."..day1
        this.canGetRewardNumber=SecretBoxManager.ShowTime-SecretBoxManager.count%SecretBoxManager.ShowTime
        this.openNumberAgainText.text=this.canGetRewardNumber
        SecretBoxManager.count=SecretBoxManager.ShowTime-this.canGetRewardNumber
    end
end

--添加事件监听（用于子类重写）
function SecretBoxPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.SecretBox.OnOpenOneReward, this.OpenOneRewardPanel)
    Game.GlobalEvent:AddEvent(GameEvent.SecretBox.OnOpenTenReward, this.OpenTenRewardPanel)
    Game.GlobalEvent:AddEvent(GameEvent.SecretBox.OnRefreshSecretBoxData, this.RefreshRedPointShow,self)
end

--移除事件监听（用于子类重写）
function SecretBoxPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.SecretBox.OnOpenOneReward,this.OpenOneRewardPanel)
    Game.GlobalEvent:RemoveEvent(GameEvent.SecretBox.OnOpenTenReward,this.OpenTenRewardPanel)
    Game.GlobalEvent:RemoveEvent(GameEvent.SecretBox.OnRefreshSecretBoxData,this.RefreshRedPointShow,self)
end

--界面打开时调用（用于子类重写）
function SecretBoxPanel:OnOpen(...)

end

function SecretBoxPanel:OnShow()
    --this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.RecruitPanel })
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.SecretBox })
    -- 打开详情界面
    --if this.TabCtrl then
    --    this.TabCtrl:ChangeTab(1)
    --end
    if(SecretBoxManager.secretBoxFreeUseTime<1 or not ActTimeCtrlManager.SingleFuncState(21)) then
        this.content1:SetActive(true)
        this.content2:SetActive(false)
    else
        this.content1:SetActive(false)
        this.content2:SetActive(true)
    end
    this:TimeFormation(SecretBoxManager.SeasonOpen,STARTTIME)
    this:TimeFormation(SecretBoxManager.SeasonEnd,ENDTIME)
    this.activityTimeText.text=year.."."..month.."."..day.."-"..year1.."."..month1.."."..day1

end


--界面关闭时调用（用于子类重写）
function SecretBoxPanel:OnClose()


    if this.shopView then
        this.shopView = SubUIManager.Close(this.shopView)
        this.shopView = nil
    end
end

--界面销毁时调用（用于子类重写）
function SecretBoxPanel:OnDestroy()

    SubUIManager.Close(this.UpView)
    --SubUIManager.Close(this.BtView)

    --ClearRedPointObject(RedPointType.SecretBox_Red1)
end

--跳转显示新手提示圈
function this.ShowGuideGo()
    JumpManager.ShowGuide(UIName.SecretBoxPanel, this.buyOneBtn)
end

return SecretBoxPanel