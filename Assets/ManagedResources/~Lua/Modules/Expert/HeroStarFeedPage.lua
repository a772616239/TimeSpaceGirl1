--- 不知道多少星级的听说是可以让英雄成长的感觉应该不怎么好玩的礼包购买页面
HeroStarFeedPage = {}

local this = HeroStarFeedPage

function HeroStarFeedPage:New(super, gameObject)
    local _o
    _o = _o or {}
    setmetatable(_o, self)
    self.__index = self
    _o.fatherClass = super
    _o.gameObject = gameObject
    _o:InitComponent(gameObject)
 
    return _o
end

--- 组件初始化， 跟主面板一起生成
function HeroStarFeedPage:InitComponent(gameObject)
    self.rewardGrid = Util.GetGameObject(gameObject, "downLayout/rect/grid")
    self.itemPre = Util.GetGameObject(gameObject, "downLayout/item")

    self.rewardItemList = {}
    self.timeList = {}
    self.isClose = true

end

function HeroStarFeedPage:OnSortingOrderChange(parentSorting)
  
end

function HeroStarFeedPage:BindEvent()
  
end



function HeroStarFeedPage:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
end

function HeroStarFeedPage:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
end

-- 充值成功回调
function HeroStarFeedPage:RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    -- OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DemonCrystal, id)--后端推了
    self:FreshRewardShow()

end

--- 这玩意点击购买之后外面会刷4遍，……，自己不主动退出。就不让他刷新
function HeroStarFeedPage:OnShow()
    if not self.isClose then return end
    
    self:FreshRewardShow()
    self:SetTimeStart()
    self.isClose = false
end

function HeroStarFeedPage:SetTimeStart()
    --- 启动一个通用定时器
    self.timer = nil
    self.timer = Timer.New(function ()
    for i = 1 , #self.timeList  do
        local value = self.timeList[i]
        if value then 
            local duration = value.endTime - PlayerManager.serverTime
            if value.isActive then 
                if duration >= 0 then 
                    value.timeComp.text = GetLanguageStrById(10541) .. TimeToDHMS(duration) .. ")"
                else
                    -- 从激活状态到结束状态

                    value.timeComp.text = ""
                    table.remove(self.timeList, i)
                    OperatingManager.RemoveItemInfoByType(GoodsTypeDef.DirectPurchaseGift, value.id)
                    self:FreshRewardShow()

                end
            else
                value.timeComp.text = ""
            end
        end
    end
    end, 1, -1, true)
    self.timer:Start()

end


function HeroStarFeedPage:FreshRewardShow()
    ---没有激活的礼包直接回到主界面
    local hasActiveGift = OperatingManager.IsHeroGiftActive()

    if not hasActiveGift then 
        if AppConst.isSDKLogin then
            UIManager.OpenPanel(UIName.ExpertPanel)
        else
            CallBackOnPanelClose(UIName.RewardItemPopup, function() 
                UIManager.OpenPanel(UIName.ExpertPanel)
            end)
        end
      
        return 
    end


    local shopData = OperatingManager.GetGiftShowData()
  
    for i = 1, #shopData do
    
        -- 重新组的数据，检查到上一个是有数据的条目时，隐藏， 然后需要清除缓存，
        if shopData[i].leftBuyTime <= 0 then
            if self.rewardItemList[i] then 
                self.rewardItemList[i]:SetActive(false)
                table.remove( self.rewardItemList, i)
            end
            break
        end


        local info = shopData[i]
        if not self.rewardItemList[i] then
            self.rewardItemList[i] = newObjToParent(self.itemPre, self.rewardGrid)
            self.rewardItemList[i]:SetActive(true)
        end 

        local item = self.rewardItemList[i]
  
        local giftName = Util.GetGameObject(item, "titleImage/root/desc"):GetComponent("Text")
        local leftTime = Util.GetGameObject(item, "titleImage/root/leftTime"):GetComponent("Text")
        local btnBuy = Util.GetGameObject(item, "getRewardBtn")
        local buyRed = Util.GetGameObject(btnBuy, "redPoint")
        local buyText = Util.GetGameObject(btnBuy, "Text"):GetComponent("Text")
        local leftNum = Util.GetGameObject(item, "left"):GetComponent("Text")
        local grid = Util.GetGameObject(item, "scroll/content")

        leftTime.text = ""
        -- if not self.timeList[info.id] then 
        self.timeList[i] = {}
        self.timeList[i].id = info.id
        self.timeList[i].timeComp = leftTime
        self.timeList[i].isActive = false
        self.timeList[i].endTime = 0
        -- end
    

  
        --- 设置购买按钮信息
        giftName.text = info.name
      
        local leftTime = info.leftBuyTime
        leftNum.gameObject:SetActive(leftTime > 0)
        leftNum.text = GetLanguageStrById(10535) .. leftTime
        Util.SetGray(btnBuy, leftTime == 0)
        --> local str = leftTime > 0 and info.price .. GetLanguageStrById(10538) or GetLanguageStrById(10543)
        local str = leftTime > 0 and MoneyUtil.GetMoney(info.price) or GetLanguageStrById(10543)

        buyText.text = str
        self.timeList[i].isActive = leftTime > 0
        self.timeList[i].endTime = leftTime > 0 and info.endTime or 0
    
        
        self:SetRewardData(item, info, grid)
    
        --- 注册购买函数
        Util.AddOnceClick(btnBuy, function ()
            if leftTime < 1 then 
                PopupTipPanel.ShowTipByLanguageId(10544)
                return 
            end

            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = info.id }, function(msg)
                    self:RechargeSuccessFunc(info.id)
                end)
            else
                NetManager.RequestBuyGiftGoods(info.id, function(msg)
                    self:RechargeSuccessFunc(info.id)
                end)
            end
        end)
    end
end

function this:SetRewardData(item, info, grid)
      --- 设置奖励内容
      --- 当前的礼包内容
      local curGiftData = info.rewardData
     
      if self.rewardItemList[item] then
          for i = 1, 4 do
              self.rewardItemList[item][i].gameObject:SetActive(false)
          end
          for i = 1, #curGiftData do
              if self.rewardItemList[item][i] then
                  self.rewardItemList[item][i]:OnOpen(false, {curGiftData[i][1],curGiftData[i][2]}, 0.75)
                  self.rewardItemList[item][i].gameObject:SetActive(true)
              end
          end
      else
          self.rewardItemList[item]={}
          for i = 1, 4 do
              self.rewardItemList[item][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
              self.rewardItemList[item][i].gameObject:SetActive(false)
          end
          for i = 1, #curGiftData do
              self.rewardItemList[item][i]:OnOpen(false, {curGiftData[i][1],curGiftData[i][2]}, 0.75)
              self.rewardItemList[item][i].gameObject:SetActive(true)
          end
      end
  
end


function HeroStarFeedPage:OnClose()
    
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    self.isClose = true
    self.timeList = {}
end

function HeroStarFeedPage:OnDestroy()
    self.rewardItemList = {}
    

end





return HeroStarFeedPage