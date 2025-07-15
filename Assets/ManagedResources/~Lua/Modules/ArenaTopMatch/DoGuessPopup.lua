require("Base/BasePanel")
local DoGuessPopup = Inherit(BasePanel)
local this = DoGuessPopup
local GUESS_COIN = ArenaTopMatchManager.GetGuessCoinID()
--初始化组件（用于子类重写）
function DoGuessPopup:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform, "tipImage/btnReturn")
    this.btnConfirm = Util.GetGameObject(this.transform, "tipImage/btnConfirm")

    this.itemBg = Util.GetGameObject(this.transform, "tipImage/item/bg"):GetComponent("Image")
    this.itemIcon = Util.GetGameObject(this.transform, "tipImage/item/icon"):GetComponent("Image")
    this.itemNum = Util.GetGameObject(this.transform, "tipImage/item/num"):GetComponent("Text")
    this.itemName = Util.GetGameObject(this.transform, "tipImage/item/name"):GetComponent("Text")

    this.slider = Util.GetGameObject(this.transform, "tipImage/Slider"):GetComponent("Slider")
    this.sliderLeftBtn = Util.GetGameObject(this.transform, "tipImage/leftbtn")
    this.sliderRightBtn = Util.GetGameObject(this.transform, "tipImage/rightbtn")
    this.sliderCount = Util.GetGameObject(this.transform, "tipImage/count"):GetComponent("Text")

    this.tips = Util.GetGameObject(this.transform, "tipImage/tips"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function DoGuessPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.btnConfirm, function()
        local betBattleInfo = ArenaTopMatchManager.GetBetBattleInfo()
        local uid = this.panelType == 1 and betBattleInfo.myInfo.uid or betBattleInfo.enemyInfo.uid
        local num = this.slider.value
        ArenaTopMatchManager.RequestBet(uid, num, function()
            ArenaTopMatchManager.SetcurIsShowDoGuessPopup(true)
            this:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10133)
           
            ArenaTopMatchManager.SetCoinNum(BagManager.GetItemCountById(GUESS_COIN))
        end)
    end)
    Util.AddClick(this.sliderLeftBtn, function()
        local curValue = this.slider.value
        if curValue <= 0 then
            return
        end
        this.slider.value = curValue - 1
    end)
    Util.AddClick(this.sliderRightBtn, function()
        local curValue = this.slider.value
        local guessCoinId = ArenaTopMatchManager.GetGuessCoinID()
        local maxNum = BagManager.GetItemCountById(guessCoinId)
        if curValue >= maxNum then
            return
        end
        this.slider.value = curValue + 1
    end)
end

--添加事件监听（用于子类重写）
function DoGuessPopup:AddListener()
end

--移除事件监听（用于子类重写）
function DoGuessPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function DoGuessPopup:OnOpen(panelType)
    this.panelType = panelType
    local guessCoinId = ArenaTopMatchManager.GetGuessCoinID()
    this.itemBg.sprite = SetFrame(guessCoinId)
    this.itemIcon.sprite = SetIcon(guessCoinId)
    this.itemName.text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, guessCoinId).Name)
    local maxNum = BagManager.GetItemCountById(guessCoinId)
    this.itemNum.text = maxNum
    this.slider.maxValue = maxNum
    this.slider.onValueChanged:AddListener(function()
        this.sliderCount.text = this.slider.value
    end)
    this.slider.value = 0
    this.sliderCount.text = 0

    -- 赔率显示
    local player = panelType == 1 and GetLanguageStrById(10139) or GetLanguageStrById(10140)
    local betRateInfo = ArenaTopMatchManager.GetBetRateInfo()
    local allCoin = betRateInfo.redCoins + betRateInfo.blueCoins
    local redWinRate = allCoin/betRateInfo.redCoins
    local blueWinRate = allCoin/betRateInfo.blueCoins
    local rate =  ArenaTopMatchManager.rate--panelType == 1 and blueWinRate or redWinRate
    this.tips.text = string.format(GetLanguageStrById(10141), player, rate)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DoGuessPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function DoGuessPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function DoGuessPopup:OnDestroy()
end

return DoGuessPopup