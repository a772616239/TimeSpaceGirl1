require("Base/BasePanel")
ArtilleryDrillsPanel = Inherit(BasePanel)
local this = ArtilleryDrillsPanel
local lotterySetting=ConfigManager.GetConfig(ConfigName.LotterySetting)
--花费道具id
local costItemId={[1]=lotterySetting[RecruitType.YanxiOne].CostItem[1][1],[2]=lotterySetting[RecruitType.ShizhanOne].CostItem[1][1]}
local type=0
this.isAttack=false

function ArtilleryDrillsPanel:InitComponent()


    --选择
    this.choose = Util.GetGameObject(self.gameObject, "choose")
    this.chooseLeftBtn = Util.GetGameObject(this.choose, "chooseLeftBtn")
    this.chooseRightBtn = Util.GetGameObject(this.choose, "chooseRightBtn")

    --开炮
    this.battle = Util.GetGameObject(self.gameObject, "battle")
    this.battleOneBtn = Util.GetGameObject(this.battle, "battleOneBtn")
    this.battleTenBtn = Util.GetGameObject(this.battle, "battleTenBtn")
    this.resetBtn = Util.GetGameObject(this.battle, "resetBtn")

    --瞄准
    this.Background = Util.GetGameObject(self.gameObject, "Background")
    this.Handle = Util.GetGameObject(self.gameObject, "Handle")

    --演习炮弹
    this.yanxiBtn = Util.GetGameObject(self.gameObject, "yanxiBtn")
    this.yanxiBulletNum = Util.GetGameObject(this.yanxiBtn, "bullet/bulletNum")
    this.yanxiSelect = Util.GetGameObject(this.yanxiBtn, "select")

    --实战炮弹
    this.shizhanBtn = Util.GetGameObject(self.gameObject, "shizhanBtn")
    this.shizhanBtnBulletNum = Util.GetGameObject(this.shizhanBtn, "bullet/bulletNum")
    this.shizhanSelect = Util.GetGameObject(this.shizhanBtn, "select")


    this.backBtn = Util.GetGameObject(self.gameObject, "BackBtn")
    this.HelpBtn=Util.GetGameObject(self.gameObject,"HelpBtn")
    this.fireEff=Util.GetGameObject(self.gameObject,"tanks/FireEff")
    this.fireEff:SetActive(false)
    this.helpPosition=this.HelpBtn:GetComponent("RectTransform").localPosition


    this.BtView =SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
end

function ArtilleryDrillsPanel:BindEvent()

    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.HelpBtn,function()

        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ArtilleryDrills,this.helpPosition.x,this.helpPosition.y) 
    end)

    Util.AddClick(this.resetBtn,function()
        -- this.Handle.transform:DOPause()
        this.InitState()

        this.Handle.transform:DOKill()
    end)

    Util.AddClick(this.chooseLeftBtn,function()
        if BagManager.GetItemCountById(costItemId[1])<lotterySetting[RecruitType.YanxiOne].CostItem[1][2] then
            PopupTipPanel.ShowTip("演习炮弹不足")
            return
        end
        type=1--演戏炮弹
        this.AttackState()
        this.AimMove()
        this.isAttack=true
        this.yanxiBtn:GetComponent("Image").sprite=Util.LoadSprite("N1_imgtxt_paojiyanxi_yanxipaodan2")
        this.shizhanBtn:GetComponent("Image").sprite=Util.LoadSprite("N1_imgtxt_paojiyanxi_shizhanpaodan1")
    
    end)

    Util.AddClick(this.chooseRightBtn,function()
        if BagManager.GetItemCountById(costItemId[2])<lotterySetting[RecruitType.ShizhanOne].CostItem[1][2] then
            PopupTipPanel.ShowTip("实战炮弹不足")
            return
        end
        type=2--实战炮弹
        this.AttackState()

        this.AimMove()
        this.isAttack=true
        this.shizhanBtn:GetComponent("Image").sprite=Util.LoadSprite("N1_imgtxt_paojiyanxi_shizhanpaodan2")
        this.yanxiBtn:GetComponent("Image").sprite=Util.LoadSprite("N1_imgtxt_paojiyanxi_yanxipaodan1")

    end)


    Util.AddClick(this.battleOneBtn,function()
        if this.isAttack==false then
            return
        end

        Log("点击单次")
        if type==1 then--演习单次
            if BagManager.GetItemCountById(costItemId[1])<lotterySetting[RecruitType.YanxiOne].CostItem[1][2] then
                PopupTipPanel.ShowTip("炮弹不足")
                return
            end
        elseif type==2 then--实战单次
            if BagManager.GetItemCountById(costItemId[2])<lotterySetting[RecruitType.ShizhanOne].CostItem[1][2] then
                PopupTipPanel.ShowTip("炮弹不足")
                return
            end
        end
        this.isAttack=false

        --固定位置
        this.Handle.transform:DOPause()
        local x=this.Handle.transform.localPosition.x
        if x>-30 and x<30 then
            --命中
            Log("单次命中坦克")
            --todo开炮播放特效 
            --显示掉落--回调（播放动画）

            if type==1 then--演习单次
                this.RequestAttack(RecruitType.YanxiOne)
            elseif type==2 then--实战单次
                this.RequestAttack(RecruitType.ShizhanOne)
            end
           
        else
            --脱靶 
            Log("单次脱靶坦克")  
            this.HandleRed()
            --todo播放失败特效
            Timer.New(function()
                Log("延时触发")
                this.isAttack=true
                this.Handle.transform:DOPlay()
                this.HandleGreen()
            end, 2, 1, true):Start()
        end
    end)

    Util.AddClick(this.battleTenBtn,function()
        if this.isAttack==false then
            return
        end

        Log("点击多次")
        if type==1 then--演习多次
            if BagManager.GetItemCountById(costItemId[1])<lotterySetting[RecruitType.YanxiTen].CostItem[1][2] then
                PopupTipPanel.ShowTip("炮弹不足")
                return
            end
        elseif type==2 then--实战多次
            if BagManager.GetItemCountById(costItemId[2])<lotterySetting[RecruitType.ShizhanTen].CostItem[1][2] then
                PopupTipPanel.ShowTip("炮弹不足")
                return
            end
        end
        this.isAttack=false

        --固定位置
        this.Handle.transform:DOPause()
        local x=this.Handle.transform.localPosition.x
        if x>-30 and x<30 then
            --命中
            Log("多次命中坦克")
            --todo开炮播放特效 
            --显示掉落--回调（播放动画）

            if type==1 then--演习单次
                this.RequestAttack(RecruitType.YanxiTen)
            elseif type==2 then--实战单次
                this.RequestAttack(RecruitType.ShizhanTen)
            end
           
        else
            --脱靶 
            Log("多次脱靶坦克")  
            this.HandleRed()
            --todo播放失败特效
            Timer.New(function()
                Log("延时触发")
                this.isAttack=true
                this.Handle.transform:DOPlay()
                this.HandleGreen()
            end, 2, 1, true):Start()
        end

        
    end)
   
end


function ArtilleryDrillsPanel:OnOpen(...)
   
end

function ArtilleryDrillsPanel:OnShow()

    this.InitState()
   
    this.RefreshBagItemNum()
   
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType =  PanelType.Main})
    this.BtView:OnOpen({ sortOrder = self.sortingOrder,panelType = PanelTypeView.MainCity })
end
function ArtilleryDrillsPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold,this.RefreshBagItemNum)
end

function ArtilleryDrillsPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold,this.RefreshBagItemNum)
end

function ArtilleryDrillsPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
    this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
end



function ArtilleryDrillsPanel:OnClose()
end

function ArtilleryDrillsPanel:OnDestroy()
    SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.UpView)
end


--初始按钮状态
function this.InitState()
    this.choose:SetActive(true)
    this.battle:SetActive(false)

    this.yanxiBtn:GetComponent("Image").sprite=Util.LoadSprite("N1_imgtxt_paojiyanxi_yanxipaodan1")
    this.shizhanBtn:GetComponent("Image").sprite=Util.LoadSprite("N1_imgtxt_paojiyanxi_shizhanpaodan1")
        
    this.Background:SetActive(false)
    this.RefreshBagItemNum()
end

function this.AttackState()
    this.choose:SetActive(false)
    this.battle:SetActive(true)
    this.Background:SetActive(true)
end

--瞄准点移动
function this.AimMove()
    -- this.Handle.transform.localPosition.x=-270
    this.Handle.transform:DOLocalMove(Vector3.New(-270,0,0), 0)
    this.Handle.transform:DOLocalMove(Vector3.New(270,0,0),2):OnComplete(function()
        this.Handle.transform:DORestart()

    end)
end

--刷新道具
function this.RefreshBagItemNum()
    this.yanxiBulletNum:GetComponent("Text").text=BagManager.GetItemCountById(costItemId[1])
    this.shizhanBtnBulletNum:GetComponent("Text").text=BagManager.GetItemCountById(costItemId[2])
end

-- function this.LingShouUpCheckRed()
--     local freeTime = 0
--     local lotterySetting=ConfigManager.GetConfig(ConfigName.LotterySetting)
--     local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.AdjutantGift)
--     if not ActData then
--         return false
--     end
--     local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",ActData.activityId)
    

-- end

--瞄准栏变绿
function this.HandleGreen()
    this.Handle:GetComponent("Image").sprite=Util.LoadSprite("N1_img_paojiyanxi_zhunxinlv")
    this.Background:GetComponent("Image").sprite=Util.LoadSprite("N1_img_paojiyanxi_zhunxinbeijing1")
end
--瞄准栏变红
function this.HandleRed()
    this.Handle:GetComponent("Image").sprite=Util.LoadSprite("N1_img_paojiyanxi_zhunxinhong")
    this.Background:GetComponent("Image").sprite=Util.LoadSprite("N1_img_paojiyanxi_zhunxinbeijing2")
end

--开炮
function this.RequestAttack(id)
    NetManager.WordExchangeBombardActivityRequest(id,function(msg)
        this.fireEff:SetActive(true)
        this.timerEffect = Timer.New(function()
            this.fireEff:SetActive(false)
            this.timerEffect:Stop()
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function ()
                this.fireEff:SetActive(false)
                this.Handle.transform:DOPlay()
                this.isAttack=true
            end)
        end, 1.5, -1, true)
        this.timerEffect:Start()
    end)
end

return ArtilleryDrillsPanel