require("Base/BasePanel")
local PokemonSummonPanel = Inherit(BasePanel)
local MazeTreasureSetting = ConfigManager.GetConfig(ConfigName.MazeTreasureSetting)
local bType={
    Btn1=1,
    Btn10=2
}
--type与lotterySetting表中的id对应
local btns={ [bType.Btn1]={name="Btn1",isInfo=GetLanguageStrById(10644)}, [bType.Btn10]={name="Btn10",isInfo=GetLanguageStrById(12182)}}

local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local lotterySetting=ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig=ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local freeTime= 0 --免费抽取次数
local isActive=false --是否激活特权
local leftTime=0 --特权剩余时间

local YaojingCallPrivilegeId = 2006

function PokemonSummonPanel:InitComponent(gameObject)
   self.btn_back=Util.GetGameObject(self.transform, "btn_back")
   self.buffImg=Util.GetGameObject(self.transform, "tokenImg"):GetComponent("Image")
   self.infoTxt=Util.GetGameObject(self.transform,"hint"):GetComponent("Text")
   self.leftTimeObj=Util.GetGameObject(self.transform, "leftTimeObj") 
   self.leftTimeTxt=Util.GetGameObject(self.transform,"leftTimeObj/leftTimeTxt"):GetComponent("Text")
   
   self.btn_shop=Util.GetGameObject(self.transform,"btn_shop")
   self.btn_reward=Util.GetGameObject(self.transform,"btn_rewardPool")

   self.btn_one=Util.GetGameObject(self.transform,"Btn1")
   self.oneHintTxt=Util.GetGameObject(self.btn_one,"Tip"):GetComponent("Text")
   self.btn_ten=Util.GetGameObject(self.transform,"Btn10")
   self.tenHintTxt=Util.GetGameObject(self.btn_ten,"Tip"):GetComponent("Text")

   self.btn_activate=Util.GetGameObject(self.transform,"btn_activate")
   Util.GetGameObject(self.btn_activate,"Text"):GetComponent("Text").text=GetLanguageStrById(50301) --m5
   
   self.limitTxt=Util.GetGameObject(self.transform,"limit"):GetComponent("Text")  
   self.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
   self.changZhuEffect = Util.GetGameObject(self.transform,"effect/Effect_Dan_changzhu")
   self.Effect_Dan_posui = Util.GetGameObject(self.transform,"effect/Effect_Dan_posui")
   self.mask = Util.GetGameObject(self.transform,"mask")
end

function PokemonSummonPanel:BindEvent()
    --奖励按钮
    Util.AddClick(self.btn_reward,function()
        UIManager.OpenPanel(UIName.RewardPreviewPopup, PRE_REWARD_POOL_TYPE.LING_SHOU)
    end)
    --激活按钮
    
    Util.AddClick(self.btn_shop,function()      
        JumpManager.GoJump(3002)
        --self.shop:SetActive(true)
        --self.btnBack:SetActive(false)
        --self.livename = "live2d_ui_h_52_xx_pf1"
        --self.liveNode = poolManager:LoadLive(self.livename, self.live.transform, Vector3.New(0.25,0.25,0.25), Vector3.New(123,214,0))
        --self:storeShow()--商店
    end)
   
    Util.AddClick(self.btn_back,function()
        self:ClosePanel()
    end)
    Util.AddClick(self.btn_activate,function()       
        --激活特权
        JumpManager.GoJump(MazeTreasureSetting[1].Jump)
    end)
end

function PokemonSummonPanel:OnShow()
    self.changZhuEffect.gameObject:SetActive(true)
    self.mask.gameObject:SetActive(false)
    self.Effect_Dan_posui.gameObject:SetActive(false)
    CheckRedPointStatus(RedPointType.Pokemon_Recruit)
    self.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShou})   

    self.infoTxt.text=GetLanguageStrById(50302) --m5
    --是否显示特权
     isActive = PrivilegeManager.GetPrivilegeOpenStatusById(3004)
    if isActive then
      self.leftTimeObj.gameObject:SetActive(true)
      Util.SetGray(self.buffImg.gameObject,false)
      leftTime = PrivilegeManager.GetPrivilegeLeftTimeById(3004)
      self.leftTimeTxt.text= string.format(GetLanguageStrById(23096), GetLeftTimeStrByDeltaTime(leftTime))
      self.btn_activate.gameObject:SetActive(false)
    else
        Util.SetGray(self.buffImg.gameObject,true)
        self.leftTimeObj.gameObject:SetActive(false)
        self.btn_activate.gameObject:SetActive(true)
    end 
    self:refreshBtnShow()--刷新按钮显示
    self:timeCountDown()--时间    
end

function PokemonSummonPanel:refreshBtnShow()
    local currLottery = ConfigManager.GetConfigData(ConfigName.LotterySetting,RecruitType.LingShowSingle)
    local freeTimesId = currLottery.FreeTimes
    local maxtimesId = currLottery.MaxTimes  --lotterySetting表中的MaxTimes对应privilegeConfig表中的id       
    local curTimes = PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)
    self.tenHintTxt.text=string.format(GetLanguageStrById(12481),PrivilegeManager.GetPrivilegeRemainValue(YaojingCallPrivilegeId), PrivilegeManager.GetPrivilegeNumber(YaojingCallPrivilegeId))  --m5
    self.limitTxt.text = GetLanguageStrById(50305)..curTimes.."/"..PrivilegeManager.GetPrivilegeNumber(maxtimesId)
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end
    --按钮赋值
    for n, m in ipairs(btns) do
        local btn = Util.GetGameObject(self.gameObject,m.name)
        local redPot = Util.GetGameObject(btn.gameObject,"RedPoint")
        local info = Util.GetGameObject(btn.gameObject,"Content/Info"):GetComponent("Text")
        local icon = Util.GetGameObject(btn.gameObject,"Content/Icon"):GetComponent("Image")
        local num = Util.GetGameObject(btn.gameObject,"Content/Num"):GetComponent("Text")
        local tip = Util.GetGameObject(btn.gameObject,"Tip"):GetComponent("Text")
        --存在免费次数 并且 免费>=1 并且是1按钮
        local isFree = freeTime and freeTime >= 1 and n == bType.Btn1
        redPot.gameObject:SetActive(isFree)
        icon.gameObject:SetActive(not isFree)
        num.gameObject:SetActive(not isFree)    

        local itemId=0
        local itemNum=0
        local type = 0
        if n == bType.Btn1 then
            type = currLottery.Id           
        else
            type = ConfigManager.GetConfigData(ConfigName.LotterySetting,RecruitType.LingShowTen).Id
        end
        local d = RecruitManager.GetExpendData(type)
        if isFree then
            info.text=" "..GetLanguageStrById(11759)
        else
            itemId = d[1]
            itemNum = d[2]

            --如果当前是用妖晶抽卡 and 激活了特权
            if itemId == 16 and isActive then
                local currPrivilege = privilegeConfig[3004]
                if currPrivilege then
                    itemNum = itemNum * (1 + currPrivilege.Condition[1][2]/10000)
                end
            end
            icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[itemId].ResourceID].Name)
            info.text = m.isInfo
            num.text = "x"..itemNum
        end

        Util.AddOnceClick(btn,function()
            local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.LingShowTen)
            if n == bType.Btn1 then
                if isFree then
                    self:Recruit(RecruitType.LingShowSingle,maxtimesId,0,0,state,freeTimesId)
                else
                    self:Recruit(RecruitType.LingShowSingle,maxtimesId,itemId,itemNum,state,freeTimesId)
                end
            elseif n==bType.Btn10 then
                self:Recruit(RecruitType.LingShowTen,maxtimesId,itemId,itemNum,state,freeTimesId)
            end
        end)
    end
end

function PokemonSummonPanel:Recruit(id,RecruitMaxtimesId,itemId,itemNum,state,freeTimesId)
    local num = 0
    if id == RecruitType.LingShowSingle then
        num = 1
    else
        num = 10
    end

    --是否超过每日最大上限
    if PrivilegeManager.GetPrivilegeRemainValue(RecruitMaxtimesId) < num then
        PopupTipPanel.ShowTipByLanguageId(11760)
        return
    end
    --是否妖晶,是否超过每日妖晶最大上限
    if itemId == 16 then
        if PrivilegeManager.GetPrivilegeRemainValue(YaojingCallPrivilegeId) < num then
            PopupTipPanel.ShowTipByLanguageId(12478)--m5
            return         
        end
    end
    if itemId ~= 0 then
        if BagManager.GetItemCountById(itemId) < itemNum then
            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[itemId].Name)..GetLanguageStrById(10492))
            return
        end
    end
    if itemId == 16 and state == 0 then
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,id,
            function()
                RecruitManager.RecruitRequest(id, 
                    function(msg)
                        self.changZhuEffect:SetActive(false)
                        self.Effect_Dan_posui:SetActive(true)
                        self.mask.gameObject:SetActive(true)
                        Timer.New(function()
                            self.mask.gameObject:SetActive(false)
                            self.Effect_Dan_posui:SetActive(false)
                            self.changZhuEffect:SetActive(true)
                            PrivilegeManager.RefreshPrivilegeUsedTimes(RecruitMaxtimesId,num)--记录抽卡次数
                            PrivilegeManager.RefreshPrivilegeUsedTimes(YaojingCallPrivilegeId,num)--记录妖晶抽卡次数
                            PokemonManager.InitPokemonsData(msg.drop.pokemon)
                            UIManager.OpenPanel(UIName.PokemonSingleResultPanel,id,msg.drop)
                            
                            --CheckRedPointStatus(RedPointType.QianKunBox)
                        end,1.2):Start()                
                    end,
                    freeTimesId,itemId,itemNum)
            end,
            itemNum)
    else
        RecruitManager.RecruitRequest(id, function(msg)
            self.changZhuEffect:SetActive(false)
            self.Effect_Dan_posui:SetActive(true)
            self.mask.gameObject:SetActive(true)
            Timer.New(function()
                self.mask.gameObject:SetActive(false)
                self.Effect_Dan_posui:SetActive(false)
                self.changZhuEffect:SetActive(true)
                PrivilegeManager.RefreshPrivilegeUsedTimes(RecruitMaxtimesId,num)--记录抽卡次数
                if itemId == 16 then
                    PrivilegeManager.RefreshPrivilegeUsedTimes(YaojingCallPrivilegeId,num)--记录妖晶抽卡次数
                end
                UIManager.OpenPanel(UIName.PokemonSingleResultPanel,id,msg.drop) 
                
            end,1.2):Start()               
            --CheckRedPointStatus(RedPointType.QianKunBox)
        end,freeTimesId,itemId,itemNum)
    end
end
--商店
function PokemonSummonPanel:storeShow()
    if not self.shopView then
        self.shopView = SubUIManager.Open(SubUIConfig.ShopView, self.content.transform,this.content)
    end
    self.shopView:ShowShop(SHOP_TYPE.QIANKUNBOX_SHOP)
end

--时间
function PokemonSummonPanel:timeCountDown()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    if self.timer2 then
        self.timer2:Stop()
        self.timer2 = nil
    end
    if freeTime>0 then
        self.oneHintTxt.text=string.format(GetLanguageStrById(50303),freeTime) --m5
    else
        local timeDown = CalculateSecondsNowTo_N_OClock(5)--领取按钮的倒计时  
        self.oneHintTxt.text =string.format(GetLanguageStrById(50304),TimeToHMS(timeDown)) --m5
        --免费次数刷新倒计时
        self.timer = Timer.New(function()                 
            if timeDown < 1 then
                self.timer:Stop()
                self.timer = nil
                return
            end
            timeDown = timeDown -1
            self.oneHintTxt.text = string.format(GetLanguageStrById(50304),TimeToHMS(timeDown)) --m5
        end, 1, -1, true)
        self.timer:Start()
    end
        --特权剩余时间倒计时
        if leftTime>0 then
            self.timer2 = Timer.New(function()                     
                if leftTime < 1 then
                    self.timer2:Stop()
                    self.timer2 = nil
                    return
                end
                leftTime = leftTime -1
                self.leftTimeTxt.text= string.format(GetLanguageStrById(23096), GetLeftTimeStrByDeltaTime(leftTime))
            end, 1, -1, true)
            self.timer2:Start()
        end
end

--- 将一段时间转换为天时分秒
function PokemonSummonPanel:TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if day <= 0 and hour <= 0 then
        return string.format(GetLanguageStrById(12231),minute, sec)
    else
        return string.format(GetLanguageStrById(12232),day, hour)
    end
end
local orginLayer = 0
function PokemonSummonPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.changZhuEffect, self.sortingOrder - orginLayer)  
    Util.AddParticleSortLayer(self.Effect_Dan_posui, self.sortingOrder - orginLayer)  
    orginLayer = self.sortingOrder
end

function PokemonSummonPanel:OnClose()
    self.gameObject:SetActive(false)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    if self.timer2 then
        self.timer2:Stop()
        self.timer2 = nil
    end
    if self.shopView then
        self.shopView = SubUIManager.Close(self.shopView)
        self.shopView = nil
    end
end
--界面销毁时调用（用于子类重写）
function PokemonSummonPanel:OnDestroy()
    orginLayer = 0
    SubUIManager.Close(self.upView)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    if self.timer2 then
        self.timer2:Stop()
        self.timer2 = nil
    end
end

return PokemonSummonPanel