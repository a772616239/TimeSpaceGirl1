require("Base/BasePanel")
ItemGetPopup = Inherit(BasePanel)
local this = ItemGetPopup
local ItemDataConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local itemListPrefab = {}

--初始化组件（用于子类重写）
function ItemGetPopup:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.itemPrefab = Util.GetGameObject(self.gameObject, "frame")

    for i = 1, 10 do
        itemListPrefab[i] =  Util.GetGameObject(self.gameObject, "ScrollView/Content/frame" .. i)
    end
end

--绑定事件（用于子类重写）
function ItemGetPopup:BindEvent()

    
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ItemGetPopup:AddListener()

end

--移除事件监听（用于子类重写）
function ItemGetPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ItemGetPopup:OnOpen(...)

    local args = {...}
    local itemList = args[1]
    this.SetItemShow(itemList)

end

--界面关闭时调用（用于子类重写）
function ItemGetPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function ItemGetPopup:OnDestroy()

end

-- 根据物品列表数据显示物品
function  this.SetItemShow(itemList)
    -- 初始化
    for i = 1, 10 do
        itemListPrefab[i].gameObject:SetActive(false)
    end
    local itemCount = 2
    for i = 1, itemCount do
        local itemId = itemList[i].id -- 增加道具的id
        local itemAdd = itemList[i].num -- 需要增加的数量
        local itemFrame = itemListPrefab[i]
        itemFrame:SetActive(true)
        local itemIcon = Util.GetGameObject(itemFrame, "icon"):GetComponent("Image")
        local itemNum = Util.GetGameObject(itemFrame, "num"):GetComponent("Text")
        local itemName = Util.GetGameObject(itemFrame, "expInfo"):GetComponent("Text")

        itemNum.text = 2 --tostring(itemAdd)
        itemName.text = GetLanguageStrById(11563)-- ItemDataConfig[itemId].Name
    end
end



return ItemGetPopup