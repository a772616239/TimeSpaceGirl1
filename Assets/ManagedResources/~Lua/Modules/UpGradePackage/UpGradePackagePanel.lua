require("Base/BasePanel")
local UpGradePackagePanel = Inherit(BasePanel)
local this = UpGradePackagePanel

local RechargeConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local TabBox = require("Modules/Common/TabBox")
local _CurPageIndex = 1
local tabInfo = {}
local cursortingOrder = 0
local curGiftList = {}
local curGiftId = nil
local curEndTime = 0
local curIndex
local curType
local fun--回调
local rechargeData
local activityType = {
    [1]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_wuxing"), showType = 15},--5星
    [2]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_liuxing"), showType = 16},--6星
    [3]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_qixing"), showType = 17},--7星
    [4]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_baxing"), showType = 18},--8星
    [5]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_jiuxing"), showType = 19},--9星
    [6]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_shixing"), showType = 20},--10星
    [7]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_shiyixing"), showType = 21},--11星
    [8]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_shierxing"), showType = 22},--12星
    [9]  = {comp = "show/bg/bg2/font", img = GetPictureFont("cn2-X1_pailian_shisanxing"), showType = 23},--13星
    -- [10] = {comp = "show/bg/bg2/font", img = GetPictureFont(""), showType = 24},--14星
    [10] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_shengji"), showType = 31},--升级
    [11] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_tongguan"), showType = 32},--通关
    [12] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_shibai"), showType = 33},--战斗失败
    -- [14] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_zhekou"), showType = 34},--超值折扣
    [13] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_shouhu"), showType = 35},--守护
    [14] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_qiyue"), showType = 36},--契约
    [15] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_xianqu"), showType = 37},--先驱
    [16] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_xinpian"), showType = 38},--芯片
    [17] = {comp = "show/bg/bg1", img = GetPictureFont("cn2-X1_pailian_pata"), showType = 39},--神之塔
}

--初始化组件（用于子类重写）
function this:InitComponent()
    this.btnClose = Util.GetGameObject(self.gameObject,"show/btnBack")

    this.pre = Util.GetGameObject(self.gameObject,"show/pre")--奖励底
    this.grid = Util.GetGameObject(self.gameObject,"show/rewards1/Grid")--奖励
    this.endTime = Util.GetGameObject(self.gameObject,"show/endTime"):GetComponent("Text")--结束时间
    this.btnBuy = Util.GetGameObject(self.gameObject,"show/Button")--购买
    this.price = Util.GetGameObject(self.gameObject,"show/Button/Text"):GetComponent("Text")--价格
    this.arrowsLeft = Util.GetGameObject(self.gameObject,"show/arrows/left")--左切换
    this.arrowsRight = Util.GetGameObject(self.gameObject,"show/arrows/right")--右切换

    this.tabbox = Util.GetGameObject(self.gameObject, "show/tabBox")
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnClose,function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnBuy,function()
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = curGiftId }, function(id)
                FirstRechargeManager.RefreshAccumRechargeValue(curGiftId)
                CheckRedPointStatus(RedPointType.GrowthPackage)--成长礼包的红点检测
                rechargeData.dynamicBuyTimes = rechargeData.dynamicBuyTimes - 1
                --判断可购买次数是否为零，是剔除礼包信息
                if rechargeData.dynamicBuyTimes < 1 then
                    OperatingManager.SetHadBuyGoodsId({curGiftId})
                    OperatingManager.RemoveItemInfoByType(GoodsTypeDef.DirectPurchaseGift, curGiftId)
                end
                -- this:Refresh()
                if self:GetInfoList() < 1 then
                    this:ClosePanel()
                    return
                end
                this.OnPageTabChange(1)
                this:OnShow()
            end)
        else
            NetManager.RequestBuyGiftGoods(curGiftId,function()
                FirstRechargeManager.RefreshAccumRechargeValue(curGiftId)
                CheckRedPointStatus(RedPointType.GrowthPackage)--成长礼包的红点检测
                rechargeData.dynamicBuyTimes = rechargeData.dynamicBuyTimes - 1
                if rechargeData.dynamicBuyTimes < 1 then
                    OperatingManager.SetHadBuyGoodsId({curGiftId})
                    OperatingManager.RemoveItemInfoByType(GoodsTypeDef.DirectPurchaseGift, curGiftId)
                end
                -- this:Refresh()
                if self:GetInfoList() < 1 then
                    this:ClosePanel()
                    return
                end
                this.OnPageTabChange(1)
                this:OnShow()
            end)
        end
    end)

    Util.AddClick(this.arrowsLeft,function()
        curIndex = curIndex - 1
        if curGiftList[curType][curIndex] then            
        else
            while(curType >= 0) do
                if not activityType[curType] then
                    curType = LengthOfTable(activityType) 
                else
                    curType = curType - 1
                end
                if curGiftList[curType] and #curGiftList[curType] > 0 then
                    curIndex =  #curGiftList[curType]   
                    break
                end
            end 
        end
        -- OperatingManager.upGradePackagePanelType = curType
        -- OperatingManager.upGradePackagePanelIndex = curIndex

        this:Refresh()

        _CurPageIndex = _CurPageIndex - 1
        if _CurPageIndex > self:GetInfoList() then
            _CurPageIndex = 1
        elseif _CurPageIndex <= 0 then
            _CurPageIndex = self:GetInfoList()
        end
        this.PageTabCtrl:ChangeTab(_CurPageIndex)
    end)

    Util.AddClick(this.arrowsRight,function()
        curIndex = curIndex + 1
        if curGiftList[curType][curIndex] then           
        else
            while(curType <= LengthOfTable(activityType) + 1) do
                if not activityType[curType] then
                    curType = 1 
                else
                    curType = curType + 1
                end
                if curGiftList[curType] and #curGiftList[curType] > 0 then
                    curIndex = 1 
                    break
                end
            end
        end
        -- OperatingManager.upGradePackagePanelType = curType
        -- OperatingManager.upGradePackagePanelIndex = curIndex
        this:Refresh()

        _CurPageIndex = _CurPageIndex + 1
        if _CurPageIndex > self:GetInfoList() then
            _CurPageIndex = 1
        elseif _CurPageIndex <= 0 then
            _CurPageIndex = self:GetInfoList()
        end
        this.PageTabCtrl:ChangeTab(_CurPageIndex)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

function this:OnSortingOrderChange()
    cursortingOrder = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function this:OnOpen(_fun)
    this:SetSortingOrder(6200)
    fun = _fun
    PatFaceManager.PatFaceback(0)
end

--获取（自己拼凑）礼包数据
function this:GetInfoList()
    local infoList = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)--拿取所有类型5礼包信息(包含需要的礼包)
    local num = 0
    for k,v in pairs(activityType) do
        curGiftList[k] = {}
        if v.showType > 0 then
            local infoList2 = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig, "PosterUiId", v.showType)
            for index, value in pairs(infoList) do
                for i = 1, #infoList2 do
                    if infoList2[i].Id == value.goodsId and value.dynamicBuyTimes > 0 then
                        table.insert(curGiftList[k],value)
                        curGiftList[k].name = infoList2[i].Name
                        num = num + 1
                    end
                end
            end
        end
    end
    return num 
end

function this:OnShow()
    this:Refresh()
    tabInfo = {}
    for i = 1, #curGiftList do
        if #curGiftList[i] > 0 then
            for j = 1, #curGiftList[i] do
                local item = {type = 0, index = 0, bg = "", name = ""}
                item.type = i
                item.index = j
                item.bg = activityType[i].bg
                item.name = curGiftList[i].name
                table.insert(tabInfo, item)
            end
        end
    end
    _CurPageIndex = #tabInfo
    this.PageTabCtrl:Init(this.tabbox, tabInfo, _CurPageIndex)
end

function this:SetCurTypeAndIndex()
    -- curType = OperatingManager.upGradePackagePanelType or 1
    -- curIndex = OperatingManager.upGradePackagePanelIndex
    if curGiftList[curType] and #curGiftList[curType] > 0 and curGiftList[curType][curIndex] then
    elseif curGiftList[curType] and #curGiftList[curType] > 0 and (not curGiftList[curType][curIndex]) then
        curIndex = #curGiftList[curType]
        return curGiftList[curType][curIndex]
    else
        for k,v in pairs(curGiftList) do
            if v and #v > 0 then
                curType = k
                curIndex = #curGiftList[curType]
                return curGiftList[curType][curIndex]
            end
        end
    end
    return curGiftList[curType][curIndex]
end

function this:Refresh()
    local num = self:GetInfoList()
    if num < 1 then
        this:ClosePanel()
        return
    end
    rechargeData = this:SetCurTypeAndIndex()

    for k, v in pairs(activityType) do
        Util.GetGameObject(self.gameObject, v.comp):SetActive(false)
    end
    Util.GetGameObject(self.gameObject, activityType[curType].comp):SetActive(true)
    Util.GetGameObject(self.gameObject, "show/bg/bg1"):SetActive(curType > 9)
    Util.GetGameObject(self.gameObject, "show/bg/bg2"):SetActive(curType <= 9)

    Util.GetGameObject(self.gameObject, activityType[curType].comp):GetComponent("Image").sprite = Util.LoadSprite(activityType[curType].img)

    curGiftId = rechargeData.goodsId

    this.arrowsLeft:SetActive(num > 1)
    this.arrowsRight:SetActive(num > 1)
    curEndTime = rechargeData.endTime
    this.endTime.text = GetLanguageStrById(11496)..TimeToHMS(curEndTime-GetTimeStamp())
    this:SetGfitShow()
    this:SetTime()
end

local _ItemViewList = {}
--设置奖励
function this:SetGfitShow()
    for k,v in pairs(_ItemViewList) do
        v.transform.parent.gameObject:SetActive(false)
        v.gameObject:SetActive(false)
    end

    for i = 1, #RechargeConfig[curGiftId].RewardShow do
        if not _ItemViewList[i] then
            local pre = newObjToParent(this.pre, this.grid.transform)
            local view = SubUIManager.Open(SubUIConfig.ItemView, pre.transform)
            _ItemViewList[i] = view
        end
        _ItemViewList[i]:OnOpen(false, RechargeConfig[curGiftId].RewardShow[i], 0.75)
        _ItemViewList[i].transform.parent.gameObject:SetActive(true)
        _ItemViewList[i].gameObject:SetActive(true)
    end
    this.price.text = MoneyUtil.GetMoney(RechargeConfig[curGiftId].Price)
end

--设置剩余时间，取剩余时间最短的礼包
function this:SetTime()
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    self.localTimer = Timer.New(function()
        if curEndTime - GetTimeStamp() < 0 then
            OperatingManager.RemoveItemInfoByType(GoodsTypeDef.DirectPurchaseGift, curGiftId)
            this:Refresh()
        end
        this.endTime.text = GetLanguageStrById(11496)..TimeToHMS(curEndTime-GetTimeStamp())
    end, 1, -1, true)
    self.localTimer:Start()
end

function this:Hide()
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if fun then
        fun()
        fun = nil
    end
    Timer.New(function ()
        Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.RefreshRightUp)
    end,1):Start()
    CheckRedPointStatus(RedPointType.PatFace)
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    cursortingOrder = 0
    _ItemViewList = {}
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end

-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    local name = Util.GetGameObject(tab, "Text"):GetComponent("Text")
    name.text = GetLanguageStrById(tabInfo[index].name)
    local select = Util.GetGameObject(tab, "select")
    Util.GetGameObject(select,"Text"):GetComponent("Text").text = name.text
    select:SetActive(status == "select")
end

-- tab改变事件
function this.OnPageTabChange(index)
    if this:GetInfoList() < 1 then
        this:ClosePanel()
        return
    end
    _CurPageIndex = index
    curType = tabInfo[_CurPageIndex].type
    curIndex = tabInfo[_CurPageIndex].index
    -- OperatingManager.upGradePackagePanelType = curType
    -- OperatingManager.upGradePackagePanelIndex = curIndex
    this:Refresh()
end

return UpGradePackagePanel