----- 公会技能重置弹窗 -----
local this = {}
--传入父脚本模块
local parent
--层级
local sortingOrder = 0
--传入不定参
local _args = {}
--传入选择英雄计算返回奖励数据列表
local dropList = {}
--item容器
local itemList = {}
local resetIndex = 1
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local fun = nil
local item,num
function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject, "TitleText"):GetComponent("Text")
    this.infoText = Util.GetGameObject(gameObject, "Body/infoText"):GetComponent("Text")
    this.cancelBtn = Util.GetGameObject(gameObject, "cancelBtn")
    this.resetBtn = Util.GetGameObject(gameObject, "resetBtn")
    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.resetBtn,function()
        if BagManager.GetItemCountById(item) < num then
            PopupTipPanel.ShowTipByLanguageId(11139)
            return
        end
        NetManager.ResetGuildSkillRequest(resetIndex,function(msg)
            PopupTipPanel.ShowTipByLanguageId(11626)
            ShopManager.AddShopItemBuyNum(SHOP_TYPE.FUNCTION_SHOP, 10028, 1)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                if fun then
                    fun()
                    fun = nil
                end
                parent:ClosePanel()
            end)
        end)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    dropList = args[1]
    resetIndex=args[2]
    fun = args[3]
    this.root.transform:GetComponent("RectTransform"):DOAnchorPosX(0, 0)
    this.titleText.text=GetLanguageStrById(11627)
    --返还比
    item,num = ShopManager.CalculateCostCountByShopId(SHOP_TYPE.FUNCTION_SHOP, 10028, 1)
    local buyNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FUNCTION_SHOP, 10028)
    local str1 =  "<color=#FFD376>".. num .."</color>"
    local str2 = "<color=#FFD376>".. GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,item).Name) .."</color>"
    local str3 = "<color=#FFD376>"..GuildSkillType[resetIndex]..GetLanguageStrById(11628)
    local str4 = "<color=#FFD376>"..tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,46).Value)/100 .."%</color>"
    local str5 = ""
    for i = 1, #dropList do
        
        if str5 == "" then
            str5 = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,dropList[i].id).Name)
        else
            str5 = str5 .. GetLanguageStrById(11629)..GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,dropList[i].id).Name)
        end
    end
    str5 = "<color=#FFD376>".. str5 .."</color>"

    local str = ""
    
    if buyNum == 0 then
        str = GetLanguageStrById(11630)..str1..str2..GetLanguageStrById(11631)..str3..GetLanguageStrById(11632)..str4..str5 .."。"
    else
        str = GetLanguageStrById(11633)..str1..str2..GetLanguageStrById(11631)..str3..GetLanguageStrById(11632)..str4..str5 .."。"
    end
    this.infoText.text = str
    local _data={}
    for i=1,#dropList do
        _data[i]={dropList[i].id,dropList[i].num}
    end
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,8,1,sortingOrder,false,_data)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this