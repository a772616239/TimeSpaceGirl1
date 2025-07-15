require("Base/BasePanel")
BazzarPopup = Inherit(BasePanel)
local this = BazzarPopup
this.itemInfo = {}
-- 当前物品在表格中的Id, 不是道具ID
local Id = 0
--初始化组件（用于子类重写）
function BazzarPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.frame = Util.GetGameObject(self.gameObject, "bg/ItemFrame"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.gameObject, "bg/ItemFrame/icon"):GetComponent("Image")
    this.num = Util.GetGameObject(self.gameObject, "bg/ItemFrame/num"):GetComponent("Text")
    this.leftBuyCount = Util.GetGameObject(self.gameObject, "bg/leftTimes"):GetComponent("Text")
    this.price = Util.GetGameObject(self.gameObject, "bg/btnBuy/price"):GetComponent("Text")
    this.costIcon = Util.GetGameObject(self.gameObject, "bg/btnBuy/icon"):GetComponent("Image")
    this.btnBuy = Util.GetGameObject(self.gameObject, "bg/btnBuy")
end

--绑定事件（用于子类重写）
function BazzarPopup:BindEvent()

    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

    Util.AddClick(this.btnBuy, function ()
        -- 发送购买协议
        -- 消耗道具
        --BagManager.UpdateItemsNum(this.itemInfo.costId, this.itemInfo.costPrice)
        --local item = {}
        --item.itemId = this.itemInfo.getId
        --item.itemNum = this.itemInfo.getNum
        --BagManager.UpdateBagData(item)
        self:ClosePanel()
        -- 购买成功，次数加1
        ShopManager.hadBoughtCount[Id] = ShopManager.hadBoughtCount[Id] + 1
        ShopManager.RefeshData()
    end)
end

--添加事件监听（用于子类重写）
function BazzarPopup:AddListener()

end

--移除事件监听（用于子类重写）
function BazzarPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function BazzarPopup:OnOpen(itemInfo, sortId)
    this.itemInfo = itemInfo
    this.InitItemShow()
    Id = sortId
end

function this.InitItemShow()
    this.frame.sprite = SetFrame(this.itemInfo.getId)
    this.icon.sprite = SetIcon(this.itemInfo.getId)
    this.num.text = this.itemInfo.getNum
    this.costIcon.sprite = SetIcon(this.itemInfo.costId)
    this.price.text = this.itemInfo.costPrice
end

--界面关闭时调用（用于子类重写）
function BazzarPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function BazzarPopup:OnDestroy()

end

return BazzarPopup