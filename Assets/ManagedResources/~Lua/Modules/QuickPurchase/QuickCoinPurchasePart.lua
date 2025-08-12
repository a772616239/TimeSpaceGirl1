 --[[
 * @ClassName QuickCommonPurchasePart
 * @Description 赞助
 * @Date 2020/4/27 18:05
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local QuickCommonPurchasePart = quick_class("QuickCommonPurchasePart")
local this = QuickCommonPurchasePart
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local mainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local panels = {}--小面板容器
local pType = {[1] = 12, [2] = 51, [3] = 52}--特权类型
local redPoint


function QuickCommonPurchasePart:ctor(mainPanel, transform)
    this.mainPanel = mainPanel
    this.transform = transform

    this.time = this.transform:Find("Time"):GetComponent("Text")
    this.helpBtn = this.transform:Find("HelpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.panel = this.transform:Find("Panel")
    for i = 1, 3 do
        panels[i] = Util.GetGameObject(this.panel,"Get"..i)
    end

    Util.AddClick(this.helpBtn.gameObject,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.BuyCoin,this.helpPosition.x,this.helpPosition.y)
    end)
end

function QuickCommonPurchasePart:OnShow(context)
    this.transform.gameObject:SetActive(true)
    this.context = context

    Game.GlobalEvent:AddEvent(GameEvent.Shop.OnShopInfoChange, this.RefreshPanel)

    redPoint = Util.GetGameObject(this.panel,"Get1/Btn/Redpot")
    redPoint:SetActive(false)
    if redPoint then
        redPoint:SetActive(true)
        BindRedPointObject(RedPointType.Revenue_Free, redPoint)
    end
    this.RefreshPanel()
end

function QuickCommonPurchasePart:OnHide()
    this.transform.gameObject:SetActive(false)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    Game.GlobalEvent:RemoveEvent(GameEvent.Shop.OnShopInfoChange ,this.RefreshPanel)

    if redPoint then
        redPoint:SetActive(false)
        ClearRedPointObject(RedPointType.Revenue_Free)
    end
end

--刷新面板
function this.RefreshPanel()
    this.SetPanel()
end

function this.SetPanel()
    this.TimeCountDown(ShopManager.CountShopRefreshLeftTime(SHOP_TYPE.BUYCOIN_SHOP))
    for i = 1, #panels do
        local o = panels[i]
        local coinNum = Util.GetGameObject(o,"Coin/Num"):GetComponent("Text")
        local btn = Util.GetGameObject(o,"Btn")
        -- m5 local btnIcon = Util.GetGameObject(o,"Btn/Icon"):GetComponent("Image")
        local btnText = Util.GetGameObject(o,"gold/Num"):GetComponent("Text") -- m5
        local timeTip = Util.GetGameObject(o,"TimeTip"):GetComponent("Text")
        local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",SHOP_TYPE.BUYCOIN_SHOP,"Limit",pType[i])--商店表数据
        local buyTime = PrivilegeManager.GetPrivilegeNumber(storeData.Limit)-ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.BUYCOIN_SHOP,storeData.Id) -- 购买次数
        local item,num,oldNum = ShopManager.CalculateCostCountByShopId(SHOP_TYPE.BUYCOIN_SHOP, storeData.Id, 1) --商品ID 价格数 旧价格

        local vipFactor = PrivilegeManager.GetPrivilegeNumber(PRIVILEGE_TYPE.BuyGoldAdd)
        local ExtraAdd = 0
        for k,v in pairs(storeData.ExtraAdd) do
            if v[1] == 3 then
              ExtraAdd = v[2]
            end
        end

        local fightId = mainLevelConfig[FightPointPassManager.curOpenFight].SortId -1
        local coin = math.floor(storeData.Goods[1][2]+(ExtraAdd*fightId))
        coinNum.text = math.floor(coin * vipFactor)
        ---coinNum.text = math.floor(storeData.Goods[1][2] * vipFactor)
        -- m5 btnIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[item].ResourceID))
        btnText.text = num --string.format(GetLanguageStrById(11688),num)
        --[[ mm5
        btnIcon.gameObject:SetActive(num~=0)
        if num= = 0 then
            btnText.text=GetLanguageStrById(11689)
        else
            btnIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[item].ResourceID))
            btnText.text = string.format(GetLanguageStrById(11688),num)
        end
        --]]
        timeTip.text = GetLanguageStrById(10535)..buyTime
        Util.GetGameObject(o,"noCoin"):SetActive(buyTime <= 0 )
        Util.AddOnceClick(btn,function()
            if buyTime <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11690)
                return
            end
            if BagManager.GetItemCountById(item) <= 0 and i ~= 1 and num ~= 0 then --i~=1 排除第一组免费领取 num~=0 排除后两组点金，第一次免费领取
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343), GetLanguageStrById(itemConfig[item].Name)))
                return
            end
            ShopManager.RequestBuyShopItem(SHOP_TYPE.BUYCOIN_SHOP, storeData.Id,1 , function()
                PrivilegeManager.RefreshPrivilegeUsedTimes(storeData.Limit, 1)
                this.RefreshPanel()
                CheckRedPointStatus(RedPointType.Revenue_Free)
                Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
                PlaySoundWithoutClick("INTERFACE_Window_OpenShouchong")

            end)
        end)
    end
end

function this.TimeCountDown(timeDown)
   if this.timer then
       this.timer:Stop()
       this.timer = nil
   end
   this.time.text = GetLanguageStrById(10028)..TimeToHMS(timeDown)
   this.timer = Timer.New(function()
       if timeDown < 1 then
           this.timer:Stop()
           this.timer = nil
           this.RefreshPanel()
           return
       end
       timeDown = timeDown - 1
       this.time.text =  GetLanguageStrById(10028)..TimeToHMS(timeDown)
   end, 1, -1, true)
   this.timer:Start()
end

return QuickCommonPurchasePart