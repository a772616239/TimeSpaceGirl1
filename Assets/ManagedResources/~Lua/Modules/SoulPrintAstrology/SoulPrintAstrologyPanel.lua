require("Base/BasePanel")
---魂印占星面板
SoulPrintAstrologyPanel = Inherit(BasePanel)
local this=SoulPrintAstrologyPanel
local orginLayer

this.curLv=0--当前等级
this.routePos={}--进度条列表
this.starsPos={}--星位置列表
this.unlockEffect={}--解锁特效列表
this.thread=nil--遮罩协程
--占星类型
this.AstrologyType={
    Once=1,
    Fifty=50,
}
--解锁类型
this.UnlockType={
    Single=1,
    Multiple=2,
    Force=3,
}
--初始化组件（用于子类重写）
function SoulPrintAstrologyPanel:InitComponent()
    orginLayer = 0
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.backBtn=Util.GetGameObject(self.gameObject,"BackBtn")
    this.effect=Util.GetGameObject(self.gameObject,"BG/Effect")--上层特效
    this.helpBtn= Util.GetGameObject(self.transform, "HelpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.forceBtn=Util.GetGameObject(self.gameObject,"RightView/ForceBtn")--强行召唤按钮
    this.shopBtn=Util.GetGameObject(self.gameObject,"RightView/ShopBtn")--魂印商城按钮
    this.warehouseBtn=Util.GetGameObject(self.gameObject,"RightView/WarehouseBtn")--魂印仓库按钮
    this.btn1=Util.GetGameObject(self.gameObject,"Btn1")
    this.btn50=Util.GetGameObject(self.gameObject,"Btn50")
    this.mask=Util.GetGameObject(self.gameObject,"Mask")
    this.coinNum=Util.GetGameObject(this.btn1,"Coin/CoinNum"):GetComponent("Text")
    for i = 1, 4 do
        this.routePos[i]=Util.GetGameObject(self.gameObject,"RoutePos").transform:GetChild(i-1).gameObject
    end
    for i = 1, 5 do
        this.starsPos[i]=Util.GetGameObject(self.gameObject,"StarsPos").transform:GetChild(i-1).gameObject
        this.unlockEffect[i]=Util.GetGameObject(this.starsPos[i],"UnlockEffect")
    end

end

--绑定事件（用于子类重写）
function SoulPrintAstrologyPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Astrology,this.helpPosition.x,this.helpPosition.y)
    end)
    --强行召唤按钮
    Util.AddClick(this.forceBtn, function()
        local costId, costNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, 10019, 1)
        CostConfirmPopup.Show(costId, costNum, GetLanguageStrById(11962), GetLanguageStrById(11963),
            function ()
                this.Force()
            end, COST_CONFIRM_TYPE.SOUL_PRINT)
    end)
    --魂印商店按钮
    Util.AddClick(this.shopBtn, function()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.SOUL_PRINT_SHOP)
    end)
    --魂印仓库按钮
    Util.AddClick(this.warehouseBtn, function()
        UIManager.OpenPanel(UIName.BagPanel, 6)
    end)
    Util.AddClick(this.btn1, function()
        this.Astrology(this.AstrologyType.Once)
    end)
    Util.AddClick(this.btn50, function()
        this.Astrology(this.AstrologyType.Fifty)
    end)
    --提示框确定按钮
    Util.AddClick(this.tipConfirmBtn, function()
        local isShow = this.tipToggle.isOn
        if isShow == true then
            local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
            RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "isShowPopUp", currentTime)
        end
        this.Force()
    end)
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, this.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(Util.GetGameObject(self.gameObject,"StarsPos"), this.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(Util.GetGameObject(self.gameObject,"RoutePos"), this.sortingOrder - orginLayer)
    orginLayer = this.sortingOrder
end

--添加事件监听（用于子类重写）
function SoulPrintAstrologyPanel:AddListener()
end

--移除事件监听（用于子类重写）
function SoulPrintAstrologyPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function SoulPrintAstrologyPanel:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SoulPrintAstrologyPanel:OnShow()
    --this.ClearPos()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })

    --获取当前占星等级
    this.curLv=SoulPrintManager.soulEquipPool
    this.ShowPos(this.curLv)
    this.RefreshConsumeCoins(this.curLv)
end

--界面关闭时调用（用于子类重写）
function SoulPrintAstrologyPanel:OnClose()
    this.ClearPos()
end

--界面销毁时调用（用于子类重写）
function SoulPrintAstrologyPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
end

--占星（1/50）
function this.Astrology(type)
    this.DelayMask(1.5)
    --判断天衍星相条件是否满足
    local curCoinNum = BagManager.GetItemCountById(14) --当前金币
    local curData=ConfigManager.GetConfigData(ConfigName.EquipTalismanaLottery,this.curLv)
    local needOnceCoin=curData.CostItem[2] --单次需要的金币
    local needFiftyCoin=curData.RepeatedlyCost[2] --多次需要的金币

    --服务器请求数据
    if type==this.AstrologyType.Once then
        if curCoinNum < needOnceCoin then
            
            UIManager.OpenPanel(UIName.QuickPurchasePanel,{ type = UpViewRechargeType.Gold })
            return
        end
        
        NetManager.GetSoulRandRequest(type, function(msg)
            SoulPrintManager.soulEquipPool=msg.pos
            
            this.ShowPosEffect(this.AstrologyType.Once,msg)
            this.RefreshConsumeCoins(msg.pos)
        end)

    elseif type ==this.AstrologyType.Fifty then
        --判断是否够抽50次
        if curCoinNum>=needFiftyCoin then--钱够50
            
            NetManager.GetSoulRandRequest(type, function(msg)
                SoulPrintManager.soulEquipPool=msg.pos
                
                this.ShowPosEffect(this.AstrologyType.Fifty,msg)
                this.RefreshConsumeCoins(msg.pos)
            end)
        else--钱不够50
            NetManager.GetSoulRandRequest(-1, function(msg)
                if msg.time==0 then
                    
                    UIManager.OpenPanel(UIName.QuickPurchasePanel,{ type = UpViewRechargeType.Gold })
                    return
                end
                SoulPrintManager.soulEquipPool=msg.pos
                
                
                this.ShowPosEffect(this.AstrologyType.Fifty,msg)
                this.RefreshConsumeCoins(msg.pos)
            end)
        end
    end
end

--强行召唤（天衍星相）
function this.Force()
    this.DelayMask(1.5)
    local curNum = BagManager.GetItemCountById(16)--当前魂晶
    local needNum= ShopManager.GetShopItemInfo(10019).Cost[2][4]--需要的数量
    if curNum < needNum then
        UIManager.OpenPanel(UIName.QuickPurchasePanel,{ type = UpViewRechargeType.DemonCrystal })
        return
    end
    NetManager.GetSoulForceRandRequest(function(msg)
        this.ShowPos(msg.pos)
        SoulPrintManager.soulEquipPool=msg.pos
        this.UnlockEffect(this.UnlockType.Force)
        this.RefreshConsumeCoins(msg.pos)
        this.RewardPopup(this.UnlockType.Force,msg,1.2)
    end)
end

--重置星级显示位置
function this.ClearPos()
    for i = 1, 5 do
        Util.GetGameObject(this.starsPos[i],"StarOpen"):SetActive(false)
    end
    for i = 1, 4 do
        Util.GetGameObject(this.routePos[i],"RouteOpen"):SetActive(false)
        Util.GetGameObject(this.routePos[i],"RouteEffect"):SetActive(false)
    end
end

--设置星级显示位置(直接显示)
function this.ShowPos(pos)
    this.ClearPos()
    this.curLv=pos
    for i = 1, pos do
        Util.GetGameObject(this.starsPos[i],"StarOpen"):SetActive(true)
        if i~=1 then
            Util.GetGameObject(this.routePos[i-1],"RouteOpen"):SetActive(true)
        end
    end
end

--设置星级显示位置（效果显示）
--type 显示类型  msg 消息体
function this.ShowPosEffect(type,msg)
    --观星一次效果
    if type==this.AstrologyType.Once then
        if msg.pos>this.curLv then --如果前进
            
            Util.GetGameObject(this.routePos[this.curLv],"RouteEffect"):SetActive(true)
            local loop= Timer.New(function()
                Util.GetGameObject(this.routePos[this.curLv-1],"RouteEffect"):SetActive(true)
                Util.GetGameObject(this.routePos[this.curLv-1],"RouteOpen"):SetActive(true)
                Util.GetGameObject(this.starsPos[this.curLv],"StarOpen"):SetActive(true)
                this.UnlockEffect(this.UnlockType.Single)
                this.RewardPopup(this.UnlockType.Single,msg,1.2)
            end,0.2,1,true)
            loop:Start()
            this.curLv=msg.pos
        elseif msg.pos==this.curLv then --如果相等
            
            this.UnlockEffect(this.UnlockType.Single)
            this.RewardPopup(this.UnlockType.Single,msg,1.2)
        elseif msg.pos<this.curLv then--如果后退
            
            this.ShowPos(msg.pos)
            this.UnlockEffect(this.UnlockType.Single)
            this.RewardPopup(this.UnlockType.Single,msg,1.2)
        end
        --观星50次效果
    elseif type==this.AstrologyType.Fifty then
        for i = 1, #this.routePos do
            Util.GetGameObject(this.routePos[i],"RouteOpen"):SetActive(true)--开启效果
        end
        for i = 1, #this.starsPos do
            Util.GetGameObject(this.starsPos[i],"StarOpen"):SetActive(true)
        end
        this.UnlockEffect(this.UnlockType.Multiple)
        this.RewardPopup(this.UnlockType.Multiple,msg,1.2)--延时弹窗
        local reductionEffect=Timer.New(function()--延时还原效果
            this.ShowPos(msg.pos)
        end,1.3,1,true)
        reductionEffect:Start()
    end
end

--解锁特效
--type 显示类型
function this.UnlockEffect(type)
    if type==this.UnlockType.Single then
        this.unlockEffect[this.curLv].gameObject:SetActive(true)
        local closeUnlockEffect=Timer.New(function()
            this.unlockEffect[this.curLv].gameObject:SetActive(false)
        end,1,1,true)
        closeUnlockEffect:Start()
    elseif type==this.UnlockType.Multiple then
        for i = 1, #this.unlockEffect do
            this.unlockEffect[i].gameObject:SetActive(true)
        end
        local closeUnlockEffect=Timer.New(function()
            for i = 1, #this.unlockEffect do
                this.unlockEffect[i].gameObject:SetActive(false)
            end
        end,1,1,true)
        closeUnlockEffect:Start()
    elseif type==this.UnlockType.Force then
        for i = 1, 4 do
            this.unlockEffect[i].gameObject:SetActive(true)
        end
        local closeUnlockEffect=Timer.New(function()
            for i = 1, 4 do
                this.unlockEffect[i].gameObject:SetActive(false)
            end
        end,1,1,true)
        closeUnlockEffect:Start()

    end
end

--奖励弹窗
--msg 消息体  delayTime 延时弹窗时间
function this.RewardPopup(type,msg,delayTime)
    local openPanel=Timer.New(function()
        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
            if type==this.UnlockType.Force then--当为强制观星时 返回
                return
            end
            if msg.time<50 and type==this.UnlockType.Multiple then--回调函数 当不足50次并且为多抽时 显示已抽几次
                PopupTipPanel.ShowTip(GetLanguageStrById(11964)..msg.time..GetLanguageStrById(11965))
            end
        end)
    end,delayTime,1,true)
    openPanel:Start()
end


--刷新占星一次消耗金币
function this.RefreshConsumeCoins(pos)
    this.coinNum.text=ConfigManager.GetConfigData(ConfigName.EquipTalismanaLottery,pos).CostItem[2]
end

--延时遮罩
function this.DelayMask(delayTime)
    this.mask.gameObject:SetActive(true)
    local closeMask=Timer.New(function()
        this.mask.gameObject:SetActive(false)
    end,delayTime,1,true)
    closeMask:Start()
end

return SoulPrintAstrologyPanel