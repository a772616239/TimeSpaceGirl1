require("Base/BasePanel")
FightMopUpEndPanel = Inherit(BasePanel)
local this=FightMopUpEndPanel
local rewardGos
local curIndex=1
local isClick=true--是否已退出扫荡
local mopUpFightId--传过来的小地图id
local needItemNum = 0--需要材料的个数
local mopUpFightData--通过小地图id 获取的关卡静态数据
local openPanel--打开扫荡界面的界面
local allRewardList ={}--后端返回的掉落数据
local msgItemInfo ={}--后端返回体力信息
local itemData = {}--关卡掉落的特殊奖励
local isShowMsgPanel = false--是否弹直接返回主角天赋界面 的二级弹窗
this.selfsortingOrder = 0
local curCanMopUpNum = 0--当前能扫荡的次数
local curOneOrTenMopUp = false--true 十扫 false 单扫
--初始化组件（用于子类重写）
function FightMopUpEndPanel:InitComponent()

    rewardGos={}
    this.levelName = Util.GetGameObject(self.transform, "Bg/nameImage/name"):GetComponent("Text")
    this.rewardGridGo = Util.GetGameObject(self.transform, "Bg/scroll/grid")
    this.rewardScrollGo = Util.GetGameObject(self.transform, "Bg/scroll")
    this.curPlayerName = Util.GetGameObject(self.transform, "Bg/curPlayer/name"):GetComponent("Text")
    this.curPlayerLv = Util.GetGameObject(self.transform, "Bg/curPlayer/lv/lv"):GetComponent("Text")
    this.curPlayerexp = Util.GetGameObject(self.transform, "Bg/curPlayer/exp"):GetComponent("Slider")
    this.curPlayerexpText=Util.GetGameObject(self.transform,"Bg/curPlayer/ExpText"):GetComponent("Text")
    for i = 1, 10 do
        rewardGos[i]= Util.GetGameObject(self.gameObject, "Bg/scroll/grid/mapAreaPre"..i)
        Util.GetGameObject(rewardGos[i].transform, "areaName"):GetComponent("Text").text=GetLanguageStrById(10311)..i..GetLanguageStrById(10312)
    end


    this.armorInfo = Util.GetGameObject(self.transform, "Bg/armorInfo/frameItemParent")
    --this.icon = Util.GetGameObject(self.transform, "Bg/armorInfo/frame/icon"):GetComponent("Image")
    --this.frameMask = Util.GetGameObject(self.transform, "Bg/armorInfo/frameMask")
    --this.frame = Util.GetGameObject(self.transform, "Bg/armorInfo/frame")
    --this.pokemonFrame = Util.GetGameObject(self.transform, "Bg/armorInfo/pokemonFrame")
    --this.pokemonImage = Util.GetGameObject(self.transform, "Bg/armorInfo/pokemonFrame/pokemonImage"):GetComponent("Image")
    --this.itenName = Util.GetGameObject(self.transform, "Bg/armorInfo/frame/name")
    this.itemName = Util.GetGameObject(self.transform, "Bg/armorInfo/armorName"):GetComponent("Text")
    this.needNum = Util.GetGameObject(self.transform, "Bg/armorInfo/needNum"):GetComponent("Text")
    --this.haveNumGo = Util.GetGameObject(self.transform, "Bg/armorInfo/haveNum")
    --this.haveNumText = Util.GetGameObject(self.transform, "Bg/armorInfo/haveNum/haveNum"):GetComponent("Text")


    this.oneBtn = Util.GetGameObject(self.transform, "Bg/oneBtn")
    this.oneBtnText = Util.GetGameObject(self.transform, "Bg/oneBtn/tiliNum"):GetComponent("Text")
    this.tenBtn = Util.GetGameObject(self.transform, "Bg/tenBtn")
    this.tenBtnText = Util.GetGameObject(self.transform, "Bg/tenBtn/tiliNum"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.transform, "Bg/btnBack")
    this.noOneImage = Util.GetGameObject(self.transform, "Bg/scroll/noOneImage")
end

--绑定事件（用于子类重写）
function FightMopUpEndPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        if isClick then
            if openPanel then
                UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                self:ClosePanel()
            else
                self:ClosePanel()
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10303)
        end
    end)
    Util.AddClick(this.oneBtn, function()
        curOneOrTenMopUp = false
        this.OneAndTenBtnClick(1)
    end)
    Util.AddClick(this.tenBtn, function()
        curOneOrTenMopUp = true
        this.OneAndTenBtnClick(10)
    end)
end

--添加事件监听（用于子类重写）
function FightMopUpEndPanel:AddListener()

end

--移除事件监听（用于子类重写）
function FightMopUpEndPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FightMopUpEndPanel:OnOpen(_mopUpFightId,_opePanel,_needItemNum)

    this.selfsortingOrder = self.sortingOrder
    this.noOneImage:SetActive(true)
    mopUpFightId =_mopUpFightId
    needItemNum = _needItemNum
    local levelConfig = ConfigManager.GetConfigData(ConfigName.LevelDifficultyConfig,mopUpFightId)
    if levelConfig then
        itemData = levelConfig.Show[1]
    end
    mopUpFightData = FightManager.GetSingleFightDataByFightId(mopUpFightId)
    --天赋需要材料信息 临时存在了背包manager信息中   在此界面进行判断 id相等时取其信息使用
    if itemData and BagManager.tianFuMaterial then
        for i, v in ipairs(BagManager.tianFuMaterial) do
            if v[1] == itemData[1] then
                needItemNum = v[2]
                openPanel = _opePanel
            end
        end
    end
    this.rewardScrollGo:GetComponent("ScrollRect").enabled = false
    this.rewardGridGo:GetComponent("RectTransform").anchoredPosition=Vector2.New(0,0)
    for i = 1, 10 do
        rewardGos[i]:SetActive(false)
    end
    allRewardList = {}
    this.ShowPanelData()
end
function this.ShowPanelData()
    this.curPlayerName.text = PlayerManager.nickName
    this.curPlayerLv.text = PlayerManager.level
    this.curPlayerexp.value= PlayerManager.exp/PlayerManager.userLevelData[PlayerManager.level].Exp
    this.curPlayerexpText.text=PlayerManager.exp.."/"..PlayerManager.userLevelData[PlayerManager.level].Exp
    if mopUpFightData then
        this.levelName.text=GetLanguageStrById(10582)..mopUpFightData.fightData.Name.."】"
        this.oneBtnText.text = mopUpFightData.fightData.Cost[1][2]+mopUpFightData.fightData.PreLevelCost[1][2]
        this.tenBtnText.text = (mopUpFightData.fightData.Cost[1][2]+mopUpFightData.fightData.PreLevelCost[1][2])*10
    end
    if itemData then
        Util.ClearChild(this.armorInfo.transform)
        SubUIManager.Open(SubUIConfig.ItemView, this.armorInfo.transform):OnOpen(false, itemData, 1,false)
        this.itemName.text = ConfigManager.GetConfigData(ConfigName.ItemConfig,itemData[1]).Name
    end
    if openPanel then
        this.needNum.text = BagManager.GetItemCountById(itemData[1]) .."/"..needItemNum
    else
        this.needNum.text = BagManager.GetItemCountById(itemData[1])
    end
    if allRewardList and #allRewardList>0 then
        this.rewardScrollGo:GetComponent("ScrollRect").enabled = false
        this.rewardGridGo:GetComponent("RectTransform").anchoredPosition=Vector2.New(0,0)
        curIndex=1
        --this.ShowDrop()
        this.ShowAllMopUpRewardList()
    end
end

local callList = Stack.New()
function this.ShowAllMopUpRewardList()
    isClick=false
    callList:Clear()
    callList:Push(function ()

        isClick=true
        this.rewardScrollGo:GetComponent("ScrollRect").enabled = true
        if openPanel and isShowMsgPanel and itemData then--如果带着需求材料进来的 材料集齐的时候 直接退出
            if BagManager.GetItemCountById(itemData[1]) >= needItemNum then
                --MsgPanel.ShowOne("已集齐材料请前往注入", function()
                    UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                    this:ClosePanel()
                --end )
            end
        end
        --如果是十连扫荡 并且已扫荡完毕 无需检测材料是否集齐的时候
        if curOneOrTenMopUp and not isShowMsgPanel and openPanel == nil then
            curCanMopUpNum = math.floor(BagManager.GetItemCountById(2) / (mopUpFightData.fightData.Cost[1][2]+mopUpFightData.fightData.PreLevelCost[1][2]))
            if curCanMopUpNum < 1 then
                UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.Energy })
                return
            end
        end

        BagManager.BackDataRefreshEnerny(msgItemInfo)
        msgItemInfo = {}
    end)
    local oldLv = 0
    local newLv = 0
    for i = #allRewardList, 1, -1 do
        callList:Push(function ()
            oldLv = PlayerManager.level
            rewardGos[i]:SetActive(true)
            this.SetGridPosY(i)
            this.SetItemShow(rewardGos[i],allRewardList[i])
            if mopUpFightData and mopUpFightData.fightData and mopUpFightData.fightData.Cost then
                --BagManager.UpdateItemsNum(2,(mopUpFightData.fightData.Cost[1][2]+mopUpFightData.fightData.PreLevelCost[1][2]))
                PlayerManager.PromoteLevel(mopUpFightData.fightData.Cost[1][2]+mopUpFightData.fightData.PreLevelCost[1][2])
            end
            this.curPlayerLv.text = PlayerManager.level
            this.curPlayerexp.value= PlayerManager.exp/PlayerManager.userLevelData[PlayerManager.level].Exp
            this.curPlayerexpText.text=PlayerManager.exp.."/"..PlayerManager.userLevelData[PlayerManager.level].Exp
            newLv = PlayerManager.level

            if oldLv < newLv then
                local curOpenFightId = FightManager.GetCurInSmallFightId()--
                local fightConFigData = ConfigManager.GetConfigData(ConfigName.LevelDifficultyConfig,curOpenFightId)
                if fightConFigData and fightConFigData.PicShow == 1 and FightManager.isOpenLevelPat then
                    UIManager.OpenPanel(UIName.FightEndLvUpPanel, oldLv, newLv, function ()
                                callList:Pop()()
                    end)
                else
                    UIManager.OpenPanel(UIName.FightEndLvUpPanel, oldLv, newLv, function ()
                        Timer.New(function ()
                            callList:Pop()()
                        end, 0.2):Start()
                    end)
                end
            else
                Timer.New(function ()
                    callList:Pop()()
                end, 0.2):Start()
            end
        end)
    end
    callList:Pop()()
end
function  this.SetGridPosY(curIndex)
    if curIndex==3 then--53  246   193
        this.rewardGridGo:GetComponent("RectTransform").anchoredPosition=Vector2.New(0,53)
    elseif curIndex>3 then
        this.rewardGridGo:GetComponent("RectTransform").anchoredPosition=Vector2.New(0,53+(199*(curIndex-3)))
    end
end
local itemListPrefab={}
-- 根据物品列表数据显示物品
function  this.SetItemShow(_parentGo,drop)
    if drop==nil then return end
    local itemDataList={}
    itemDataList=BagManager.GetTableByBackDropData(drop)
    Util.ClearChild(Util.GetGameObject(_parentGo, "rect/grid").transform)
    for i = 1, #itemDataList do
        local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(_parentGo, "rect/grid").transform)
        view:OnOpen(true,itemDataList[i],0.75)
    end
    if openPanel then
        this.needNum.text = BagManager.GetItemCountById(itemData[1]) .."/"..needItemNum
    else
        this.needNum.text = BagManager.GetItemCountById(itemData[1])
    end
end

function this.OneAndTenBtnClick(_num)
    this.noOneImage:SetActive(false)
    if isClick then
        --体力不足时直接弹 体力购买界面
        curCanMopUpNum = _num
        if BagManager.GetItemCountById(2) < (mopUpFightData.fightData.Cost[1][2]+mopUpFightData.fightData.PreLevelCost[1][2])*_num then
            curCanMopUpNum = math.floor(BagManager.GetItemCountById(2) / (mopUpFightData.fightData.Cost[1][2]+mopUpFightData.fightData.PreLevelCost[1][2]))
            if curCanMopUpNum < 1 then
                UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.Energy })
                return
            end
        end
        --隐藏十个缓存奖励条目
        for i = 1, 10 do
            rewardGos[i]:SetActive(false)
        end
        --
        local itemId = 0
        local itemNum = 0--扫荡前 数量就满足 就不中通打断  并且穿0
        isShowMsgPanel = false
        if openPanel then
            if BagManager.GetItemCountById(itemData[1]) < needItemNum then--如果一开始背包数量小于需求数量
                isShowMsgPanel = true--当扫荡达到要求是  弹二级弹窗跳转天赋注入界面
                itemId = itemData[1]
                itemNum = needItemNum
            end
        end
        --扫荡协议
        NetManager.GetMopUpFightDataRequest(1,mopUpFightData.fightId,curCanMopUpNum,itemId,itemNum,function(msg)
            allRewardList = {msg.Drop, msg.randomDrop}
            table.insert(msgItemInfo,msg.ItemInfo)
            this.ShowPanelData()
        end)
    else
        PopupTipPanel.ShowTipByLanguageId(10303)
    end

end
--界面关闭时调用（用于子类重写）
function FightMopUpEndPanel:OnClose()

    openPanel = nil
    curOneOrTenMopUp = false
    this.noOneImage:SetActive(false)
    if PlayerManager.curLevelAndExp then
        if PlayerManager.curLevelAndExp.level and PlayerManager.curLevelAndExp.level > 0 then
            PlayerManager.BcakUpdateUserExp(PlayerManager.curLevelAndExp)
        end
    end
end

--界面销毁时调用（用于子类重写）
function FightMopUpEndPanel:OnDestroy()

end

return FightMopUpEndPanel