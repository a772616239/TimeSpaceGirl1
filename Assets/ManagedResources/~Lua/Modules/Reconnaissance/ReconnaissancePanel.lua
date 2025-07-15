require("Base/BasePanel")
ReconnaissancePanel = Inherit(BasePanel)
local this = ReconnaissancePanel
local i = 0
local canDrag = true
local AllActSetConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
local EpicBattleConfig = ConfigManager.GetConfig(ConfigName.EpicBattleConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local QAConfig = ConfigManager.GetConfig(ConfigName.QAConfig)
local total--累计次数
local alrealyGetBox = {}--已领宝箱
local minimumCount--保底次数
local orginLayer = 0
local boxList = {}
-- local boxvalue = {[1]=20,[2]=40,[3]=80,[4]=100}
local boxvalue
this.awardList = {}
local epicBattleConfigData


function ReconnaissancePanel:InitComponent()
    -- this.mask = Util.GetGameObject(self.transform,"Mask")
    this.tip = Util.GetGameObject(self.transform, "Bg/tip")
    this.backBtn = Util.GetGameObject(self.transform, "backBtn")

    this.slider = Util.GetGameObject(self.transform, "Box/Slider"):GetComponent("Slider")
    this.numText = Util.GetGameObject(self.transform, "Box/num/Text")
    this.RewardBox = Util.GetGameObject(self.transform, "Box/RewardBox")
    for i = 1, 4 do
        local box = Util.GetGameObject(this.RewardBox, "Item"..i)
        table.insert(boxList,box)
    end

    this.boxRewardPanel = Util.GetGameObject(self.transform, "boxRewardPanel")
    this.boxrewardPanelMask = Util.GetGameObject(this.boxRewardPanel,"Mask")
    this.ItemViewParent = Util.GetGameObject(this.boxRewardPanel,"ItemViewParent")
    this.rewardItemView = SubUIManager.Open(SubUIConfig.ItemView,this.ItemViewParent.transform)
    
    -- this.SelfIcon = Util.GetGameObject(self.transform, "SelfIconBg/SelfIcon")
    -- this.IconNum = Util.GetGameObject(self.transform, "SelfIconBg/IconNum")
    -- this.buyBtn = Util.GetGameObject(self.transform, "SelfIconBg/buyBtn")
   
    this.scroll = Util.GetGameObject(self.transform, "award/Scroll/content")

    this.RewardPanel = Util.GetGameObject(self.transform, "RewardPanel")
    this.RewardPanelMask = Util.GetGameObject(this.RewardPanel, "Mask")
    this.RewardPanelText = Util.GetGameObject(this.RewardPanel, "Text")

    --this.upTip = Util.GetGameObject(self.transform, "upTip")
    -- this.upTipText1 = Util.GetGameObject(self.transform, "upTip/text1")
    -- this.upTipText2 = Util.GetGameObject(self.transform, "upTip/text2")

    --this.downTip = Util.GetGameObject(self.transform, "downTip")
    this.downTipText = Util.GetGameObject(self.transform, "Tip")


    this.previewBtn = Util.GetGameObject(self.transform, "previewBtn")
    this.recordBtn = Util.GetGameObject(self.transform, "recordBtn")

    this.btn1 = Util.GetGameObject(self.transform, "Btns/Btn1")
    this.btn1Info = Util.GetGameObject(this.btn1, "Bg/Info")
    this.btn1Icon = Util.GetGameObject(this.btn1, "Bg/Num/Icon")
    this.btn1Num = Util.GetGameObject(this.btn1, "Bg/Num")
    this.btn1Red = Util.GetGameObject(this.btn1, "RedPoint")

    this.btn10 = Util.GetGameObject(self.transform, "Btns/Btn10")
    this.btn10Info = Util.GetGameObject(this.btn10, "Bg/Info")
    this.btn10Icon = Util.GetGameObject(this.btn10, "Bg/Num/Icon")
    this.btn10Num = Util.GetGameObject(this.btn10, "Bg/Num")

    this.moveBg = Util.GetGameObject(self.transform,"bg/move")

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight})
end

function ReconnaissancePanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    end)
 
    --勘探记录
    Util.AddClick(this.recordBtn, function()
       UIManager.OpenPanel(UIName.ReconnaissanceRecord)
    end)

   --奖励预览
    Util.AddClick(this.previewBtn, function()
        this.RewardPanelText:GetComponent("Text").text = GetLanguageStrById(QAConfig[115].content)--epicBattleConfigData.ChanceDec
        this.RewardPanel:SetActive(true)
    end)

    -- --道具购买
    -- Util.AddClick(this.buyBtn, function()
    --     UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,this.itemId)
    -- end)

    Util.AddClick(this.RewardPanelMask, function()
        this.RewardPanel:SetActive(false)
    end)

    Util.AddClick(this.boxrewardPanelMask, function()
        this.boxRewardPanel.gameObject:SetActive(false)
    end)

    BindRedPointObject(RedPointType.Culturalrelics, this.btn1Red)
end

function ReconnaissancePanel:AddListener()
   -- Game.GlobalEvent:AddEvent(GameEvent.Recruit.OnRecruitRefreshData, this.UpdatePanelData)
end

function ReconnaissancePanel:RemoveListener()
   -- Game.GlobalEvent:RemoveEvent(GameEvent.Recruit.OnRecruitRefreshData, this.UpdatePanelData)
end
function ReconnaissancePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.UI_effect_RecruitPanel_box_normal, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(self.UI_effect_RecruitPanel_box_open, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(self.UI_effect_RecruitPanel_particle, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function ReconnaissancePanel:OnShow(...)
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })

    this.boxRewardPanel:SetActive(false)
    this.RewardPanel:SetActive(false)
    epicBattleConfigData = EpicBattleConfig[1]
    boxvalue = epicBattleConfigData.TargetAward

    -- NetManager.WorldProspectInfoRequest(function(msg)
    --   total=msg.totalCount
    --   alrealyGetBox = msg.getCount
    --   minimumCount = msg.haveCount

      this.UpdateData()
    -- end)

    --两个提示栏信息(玩家获取游戏物品信息)

    --五点刷新信息
    this.MoveBg()

end

function ReconnaissancePanel:OnClose()
    if this.tween then
        this.tween:Kill()
        this.tween = nil
    end
    if this.time then
        this.time:Stop()
        this.time = nil
    end
end

function ReconnaissancePanel:OnDestroy()
    this.awardList = {}
    boxList = {}

    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.HeadFrameView)

    if this.tween then
        this.tween:Kill()
        this.tween = nil
    end
    if this.time then
        this.time:Stop()
        this.time = nil
    end
end

function this.UpdateData()
    NetManager.WorldProspectInfoRequest(function(msg)
      total = msg.totalCount
      alrealyGetBox = msg.getCount
      minimumCount = msg.haveCount

      this.UpdatePanelData()--面板
      this.SetRewardBox()--宝盒

      --刷新芯片红点
      if RoleInfoPanel then
            RoleInfoPanel:RefreshRedPoint()
            RoleInfoPanel:RefreshChipRedPoint()
      end
     
      
    end)
end

function this.UpdatePanelData()
    CheckRedPointStatus(RedPointType.Culturalrelics)
    local awardTrueValue = epicBattleConfigData.AwardTrue
    local oneExpend = lotterySetting[awardTrueValue[1]]
    local tenExpend = lotterySetting[awardTrueValue[2]]

    local oneFreeId = oneExpend.FreeTimes
    --local tenFreeId = tenExpend.FreeTimes

    local oneFreeTime
    local tenFreeTime
    if oneFreeId ~= nil and oneFreeId ~= 0 then
        oneFreeTime = PrivilegeManager.GetPrivilegeRemainValue(oneFreeId)
    end
    this.btn1Icon.gameObject:SetActive(oneFreeTime <= 0)
    this.btn1Num.gameObject:SetActive(oneFreeTime <= 0)
    this.btn1Info:GetComponent("Text").text = oneFreeTime > 0 and GetLanguageStrById(23107) or GetLanguageStrById(23108)

    local oneCost = RecruitManager.GetExpendData(epicBattleConfigData.AwardTrue[1])
    this.btn1Icon:GetComponent("Image").sprite = Util.LoadSprite(artResourcesConfig[itemConfig[oneCost[1]].ResourceID].Name)
    this.btn1Num:GetComponent("Text").text = "×"..oneCost[2]    

    this.btn10Info:GetComponent("Text").text= GetLanguageStrById(23109)
    local tenCost,v1=RecruitManager.GetExpendData(epicBattleConfigData.AwardTrue[2])
    this.btn10Icon:GetComponent("Image").sprite=Util.LoadSprite(artResourcesConfig[itemConfig[tenCost[1]].ResourceID].Name)
    this.btn10Num:GetComponent("Text").text="×"..tenCost[2]

    Util.AddOnceClick(this.btn1, function()
        local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.ProveUpOne)
        if oneFreeTime <= 0 then
            if BagManager.GetItemCountById(oneCost[1]) < oneCost[2] then
                PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[oneCost[1]].Name)..GetLanguageStrById(10492))
                return
            end
        end
        local type--消耗类型
        if oneCost[1] == 16 then
            type = 2
        else
            type = 1
        end
        local countType--勘察次数
        if oneFreeTime > 0 then
            countType = 0
        else
            countType = awardTrueValue[1]
        end
        local recruitOne = function()
            NetManager.WorldProspectRequest(type,countType,function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                    if oneFreeTime > 0 then
                        PrivilegeManager.RefreshPrivilegeUsedTimes(oneFreeId,1)--刷新抽卡次数
                    end
                    this.UpdateData()
                end)
            end)
        end

        --type:1=遗址地图消耗,2=钻石消耗  countType勘察数量 0=免费， 34=单次，35=10连
        -- local recruitOne = function()
        --end
        if state == 0 and oneCost[1] ==16 and oneFreeTime <= 0  then
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.Recruit,RecruitType.ProveUpOne,recruitOne)
        else
            recruitOne()
        end
    end)

    Util.AddOnceClick(this.btn10, function()
        local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.ProveUpTen)

        local lotterySettingConfig = G_LotterySetting[epicBattleConfigData.AwardTrue[2]]
        local count = BagManager.GetItemCountById(lotterySettingConfig.CostItem[1][1])
        local singleCost = lotterySettingConfig.CostItem[2][2]/lotterySettingConfig.PerCount
        if count > lotterySettingConfig.PerCount then
            count = lotterySettingConfig.PerCount
        end
        local deficiencyCount = lotterySettingConfig.PerCount-count
        if BagManager.GetItemCountById(tenCost[1]) < deficiencyCount*singleCost then
            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[tenCost[1]].Name)..GetLanguageStrById(10492))
            return
        end

        local type--消耗类型
        if tenCost[1] == 16 then
            type = 2
        else
            type = 1
        end

        local recruitTen = function()
            NetManager.WorldProspectRequest(type,awardTrueValue[2],function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                    this.UpdateData()
                end)
            end)
        end
    
        if tenCost[1] ==16 and BagManager.GetItemCountById(v1) > 0 then
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.Recruit, RecruitType.ProveUpTen, recruitTen)
        elseif state == 0 and tenCost[1] == 16 and BagManager.GetItemCountById(v1) <= 0 then
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.Recruit, RecruitType.ProveUpTen, recruitTen)
        else
            recruitTen()
        end
    end)

    --自身道具展示
    -- this.itemId = oneExpend.CostItem[1][1]
    -- this.SelfIcon:GetComponent("Image").sprite = Util.LoadSprite(artResourcesConfig[itemConfig[this.itemId].ResourceID].Name)
    -- this.IconNum:GetComponent("Text").text = BagManager.GetItemCountById(this.itemId)

    --奖励预览
    local awardListData = epicBattleConfigData.AwardShow 
    for i = 1, #awardListData do
        if this.awardList[i] then
            this.awardList[i]:OnOpen(false,awardListData[i],0.7,false,false,false,this.selfsortingOrder)
        else
            local view = SubUIManager.Open(SubUIConfig.ItemView,this.scroll.transform)
            view:OnOpen(false,awardListData[i],0.7,false,false,false,this.selfsortingOrder)
            this.awardList[i]=view
        end
    end

    --描述
    -- this.tip:GetComponent("Text").text = GetLanguageStrById(epicBattleConfigData.dec)

    --提示栏
    this.downTipText:GetComponent("Text").text = string.format(GetLanguageStrById(epicBattleConfigData.Language),"<color=#ffd12b>" .. minimumCount .. "</color>")

    --进度条
    if total > 100 then
        local isReset = true
        for i = 1, #boxList do
            if this.GetBoxState(boxvalue[i][1])==0 then
                isReset = false
            end
        end
        if isReset == false then
            this.slider.value = total/100
            this.numText:GetComponent("Text").text = total
        else
            this.slider.value = total%100/100
            this.numText:GetComponent("Text").text = total % 100
        end
    else
        this.slider.value = total/100
        this.numText:GetComponent("Text").text = total
    end
end

local oldName
local oldItem
local oldNum
--推送玩家获得道具内容
function this.updataUpTipText(msg)
    -- if oldName==nil or oldNum==nil or oldItem==nil then
    --     this.upTipText1:GetComponent("Text").text=""
    -- else
    --     this.upTipText1:GetComponent("Text").text=string.format(23111,oldName,oldItem,oldNum)
    -- end

    for i = 1,#msg.goodsReward do
       -- this.upTipText1:GetComponent("Text").text=string.format(23111,oldName,itemConfig[oldItem].Name,oldNum)

        if oldName == nil or oldNum == nil or oldItem == nil then
        --    this.upTipText1:GetComponent("Text").text = ""
        else
        --    this.upTipText1:GetComponent("Text").text = string.format(GetLanguageStrById(23111),oldName,oldItem,oldNum)
        end

        -- this.upTipText2:GetComponent("Text").text = string.format(GetLanguageStrById(23111),msg.goodsReward[i].name,GetLanguageStrById(itemConfig[msg.goodsReward[i].goodsId].Name),msg.goodsReward[i].count)
        oldName = msg.goodsReward[i].name
        oldItem = GetLanguageStrById(itemConfig[msg.goodsReward[i].goodsId].Name)
        oldNum = msg.goodsReward[i].count
    end

    -- for k,v in pairs(msg) do
    --     this.upTipText1:GetComponent("Text").text=string.format(23111,oldName,oldItem,oldNum)

    --     this.upTipText2:GetComponent("Text").text=string.format(23111,v.name,v.goodsId,v.count)
    --     oldName=v.name
    --     oldItem=v.goodsId
    --     oldNum=v.count
    -- end
end

--宝箱状态
function this.SetRewardBox()
    for i = 1, #boxList do
        Util.GetGameObject(boxList[i],"value"):GetComponent("Text").text = boxvalue[i][1]

        --显示奖盒红点
        --BG1:灰色合箱子 BG2:灰色开箱子 BG3:彩色合箱子
        if total >= boxvalue[i][1] then
            if this.GetBoxState(boxvalue[i][1]) == 0 then
                Util.GetGameObject(boxList[i],"BG1"):SetActive(true)
                Util.GetGameObject(boxList[i],"BG2"):SetActive(false)
            else--奖励已领取
                Util.GetGameObject(boxList[i],"BG1"):SetActive(false)
                Util.GetGameObject(boxList[i],"BG2"):SetActive(true)
            end
            Util.GetGameObject(boxList[i],"redPoint"):SetActive(this.GetBoxState(boxvalue[i][1]) == 0)
        else--幸运值未超过该箱子
            Util.GetGameObject(boxList[i],"BG1"):SetActive(true)
            Util.GetGameObject(boxList[i],"BG2"):SetActive(false)
            Util.GetGameObject(boxList[i],"redPoint"):SetActive(false)
        end

        Util.AddOnceClick(boxList[i], function()
            --满足领取条件
            if total >= boxvalue[i][1] then
                --奖励未领取 先请求领取
                if this.GetBoxState(boxvalue[i][1]) == 0 then
                    NetManager.WorldProspectTotalRewardRequest(boxvalue[i][1],function(msg)
                        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                            PopupTipPanel.ShowTipByLanguageId(23112)
                            this.UpdateData()
            
                        end)
                    end)
                else--奖励已领取 可预览
                    this.BoxShow(i)
                end
            else
                --奖励不可领，可预览
                this.BoxShow(i)
            end
        end)
    end
end   

function this.GetBoxState(boxCount)
    --0未领取 --1领取
    if alrealyGetBox and #alrealyGetBox > 0  then
        for k,v in ipairs(alrealyGetBox) do
            if boxCount == v then
                return 1
            end
        end
    end
    return 0
end

--宝箱预览
function this.BoxShow(boxId)
    this.boxRewardPanel:SetActive(true)
    local tab = {boxvalue[boxId][2],boxvalue[boxId][3]}
    this.rewardItemView:OnOpen(false, {tab[1],tab[2]},0.7, false, false, false,this.selfsortingOrder)
end

local pos = 956
function this.MoveBg()
    this.moveTween()

    if this.time then
        this.time:Stop()
        this.time = nil
    end
    this.time = Timer.New(function ()
        if this.moveBg.transform.localPosition.x == 956 then
            pos = -956
            this.moveTween()
        elseif this.moveBg.transform.localPosition.x == -956 then
            pos = 956
            this.moveTween()
        end
    end, 0.5, -1):Start()
end

function this.moveTween()
    if this.tween then
        this.tween:Kill()
        this.tween = nil
    end
    this.tween = DoTween.To(
        DG.Tweening.Core.DOGetter_float(
            function ()
                return this.moveBg.transform.localPosition.x
            end),
        DG.Tweening.Core.DOSetter_float(
            function (t)
                this.moveBg.transform.localPosition = Vector3(t, this.moveBg.transform.localPosition.y, 0)
            end),
        pos, 15):SetEase(Ease.Linear)
end

return ReconnaissancePanel