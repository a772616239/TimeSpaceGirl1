require("Base/BasePanel")
local XiaoYaoEventPanel = Inherit(BasePanel)
local this = XiaoYaoEventPanel
local triggertype = 0  --0：游历成功   大于0：触发仙缘
--初始化组件（用于子类重写）
function this:InitComponent()
    -- this.spLoader = SpriteLoader.New()

    this.btnBack = Util.GetGameObject(self.transform, "closeBtn")
    -- this.title = Util.GetGameObject(self.transform, "bg/title"):GetComponent("Image")
    this.grid = Util.GetGameObject(self.transform, "bg/grid")
    this.title = Util.GetGameObject(self.transform, "bg/Text"):GetComponent("Text")
    this.xianyuan = Util.GetGameObject(self.transform, "bg/xianyuan")
    this.eventName = Util.GetGameObject(self.transform, "bg/xianyuan/name"):GetComponent("Text")
    this.eventIcon = Util.GetGameObject(self.transform, "bg/xianyuan/icon"):GetComponent("Image")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
        if triggertype == 0 then
            XiaoYaoManager.OpenMapList()
        end
    end)
end

--界面打开时调用（用于子类重写）
function this:OnOpen(_type,_data)
    triggertype = _type  
    this.title.text = GetLanguageStrById(50341)
    if _type > 0 then
        -- this.title.sprite = Util.LoadSprite(GetPictureFont("x_xiaoyaoyou_chufaxianyuan"))
        this.grid:SetActive(false)
        this.xianyuan:SetActive(true)
        this.eventName.text = string.format("★%s★",GetLanguageStrById(_data.Desc))
        this.eventIcon.sprite = Util.LoadSprite(_data.EventPointBg)
    else
        -- this.title.sprite=Util.LoadSprite(GetPictureFont("x_xiaoyaoyou_youlichenggong"))
        this.grid:SetActive(true)
        this.xianyuan:SetActive(false)
        local showItemdata = this.GetDropReward(_data)
        local starItemDataList = BagManager.GetItemListFromTempBag(_data)
        for i = 1, #starItemDataList do
            this.SetItemData2(starItemDataList[i])
        end
        -- Log("终极大奖："..#_data.itemlist)
        -- Log("终极大奖："..#showItemdata)
        if showItemdata and #showItemdata > 0 then
            for i = 1, #showItemdata do
                -- Log("终极大奖："..showItemdata[i][1])
                local _rewardObj = SubUIManager.Open(SubUIConfig.ItemView, this.grid.transform)
                _rewardObj:OnOpen(false,showItemdata[i],1)
            end
        end
    end
end
--存储本地
function this.SetItemData2(itemdata)
    if itemdata.itemType == 1 then
       --后端更新
    elseif itemdata.itemType == 2 then
            EquipManager.UpdateEquipData(itemdata.backData)
    elseif itemdata.itemType == 3 then
            HeroManager.UpdateHeroDatas(itemdata.backData)
    elseif itemdata.itemType == 4 then
            TalismanManager.InitUpdateSingleTalismanData(itemdata.backData)
    elseif itemdata.itemType == 5 then
            EquipTreasureManager.InitSingleTreasureData(itemdata.backData)
    elseif itemdata.itemType == 6 then
            PokemonManager.UpdatePokemonDatas(itemdata.backData,true)
    end
end
function this.GetDropReward(_drop)
    local _rewardList = {}
    if _drop.itemlist then
        for i = 1, #_drop.itemlist  do
            local _rewardData = {}
            _rewardData[1] = _drop.itemlist[i].itemId
            _rewardData[2] = _drop.itemlist[i].itemNum
            table.insert(_rewardList,_rewardData)
        end
    end
    if _drop.equipId  then
        for i = 1, #_drop.equipId  do
            local _rewardData = {}
            _rewardData[1] = _drop.equipId[i].equipId--id
            _rewardData[2] = 1
            table.insert(_rewardList,_rewardData)
        end
    end
    if _drop.Hero  then
        for i = 1, #_drop.Hero  do
            local _rewardData = {}
            _rewardData[1] = _drop.Hero[i].heroId--id
            _rewardData[2] = 1
            table.insert(_rewardList,_rewardData)
        end
    end
    if _drop.soulEquip  then
        for i = 1, #_drop.soulEquip  do
            local _rewardData={}
            _rewardData[1] = _drop.soulEquip[i].equipId--id
            _rewardData[2] = 1
            table.insert(_rewardList,_rewardData)
        end
    end
    return _rewardList
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()

end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if triggertype>0 then
        Game.GlobalEvent:DispatchEvent(GameEvent.XiaoYao.PlayEventEffect)
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    while(this.grid.transform.childCount > 0)
    do
        destroy(this.grid.transform:GetChild(0).gameObject)
    end
    -- this.spLoader:Destroy()
end

return XiaoYaoEventPanel