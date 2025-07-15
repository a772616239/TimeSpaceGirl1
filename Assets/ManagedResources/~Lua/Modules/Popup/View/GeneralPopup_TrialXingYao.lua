----- 试练性药 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0

local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local trialSetting = ConfigManager.GetConfig(ConfigName.TrialSetting)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local item
local heroList = {} --英雄预设容器
local oldChoosed = nil--上一个选中英雄
local selectHeroDid --选中英雄did
local itemId = 0 --消耗道具ID
local itemNum = 0 --消耗道具数量
local optionType = { --选择类型
    First = 0,
    Refresh = 1,
}

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.body = Util.GetGameObject(gameObject,"Body")
    this.item = Util.GetGameObject(this.body,"Item")
    this.desc = Util.GetGameObject(this.body,"Desc"):GetComponent("Text")
    this.time = Util.GetGameObject(this.body,"Time"):GetComponent("Text")
    this.num = Util.GetGameObject(this.body,"Num"):GetComponent("Text")
    this.addBtn = Util.GetGameObject(this.body,"Add")
    this.grid = Util.GetGameObject(gameObject, "Root/Grid")
    this.pre = Util.GetGameObject(gameObject,"Root/Grid/Pre")
    this.cancelBtn = Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn = Util.GetGameObject(gameObject,"ConfirmBtn")

    item = SubUIManager.Open(SubUIConfig.ItemView, this.item.transform)
end

function this:BindEvent()
    --取消按钮
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    --使用按钮
    Util.AddClick(this.confirmBtn,function()
        local maxNum = trialSetting[1].HealingId[2]
        local curHeroHp = 0
        for i, v in ipairs(MapManager.trialHeroInfo) do
            if selectHeroDid == v.heroId then
                curHeroHp = v.heroHp
                if v.heroHp <= 0 then
                    PopupTipPanel.ShowTipByLanguageId(11650)
                    return
                end
            end
        end
        if (maxNum - MapManager.addHpCount) <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11651)
            return
        end
        if BagManager.GetItemCountById(itemId) <= 0 then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11652), GetLanguageStrById(itemConfig[itemId].Name)))
            return
        end
        if curHeroHp >= 10000 then
            PopupTipPanel.ShowTipByLanguageId(11653)
            return
        end
        NetManager.UseAddHpItemRequest(selectHeroDid, function(msg)
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11654), GetLanguageStrById(itemConfig[itemId].Name)))
            MapManager.addHpCount = MapManager.addHpCount + 1
            -- curHeroHp = curHeroHp + 5000  --5000增加的血量也是要配表的
            -- if curHeroHp >= 10000 then
            --     curHeroHp = 10000
            -- end
            curHeroHp = msg.curHp
            MapTrialManager.SetHeroHp({curHeroHp}, selectHeroDid)
            Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
        end)
    end)
    --购买道具按钮
    Util.AddClick(this.addBtn,function()
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.XingYao })
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.RefreshPanel)--监听背包信息改变刷新 用于回春散数量刷新
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.RefreshPanel)
end

function this:OnShow(_parent,...)
    oldChoosed = nil
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local _args = {...}
    itemId = trialSetting[1].HealingId[1]
    itemNum = BagManager.GetItemCountById(itemId)
    this.RefreshPanel()
end

function this:OnClose()
end

function this:OnDestroy()
    item = nil
    heroList = {}
end

--刷新面板
function this.RefreshPanel()
    this.titleText.text = GetLanguageStrById(11655)
    item:OnOpen(false, {itemId,1}, 1.2,false,false,false,sortingOrder)
    item:Reset({itemId,1},ItemType.NoType,{nil,false,nil,false})
    this.desc.text = GetLanguageStrById(itemConfig[itemId].ItemDescribe)
    this.time.text = GetLanguageStrById(11656) .. (trialSetting[1].HealingId[2] - MapManager.addHpCount)
    this.num.text = GetLanguageStrById(11657) .. BagManager.GetItemCountById(itemId)

    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
    
    for i, v in ipairs(MapManager.trialHeroInfo) do
        local o = heroList[i]
        if not o then
            o = newObjToParent(this.pre,this.grid)
            o.name = "pre"..i
            heroList[i] = o
        end
        o.gameObject:SetActive(true)

        local frame = Util.GetGameObject(o,"frame"):GetComponent("Image")
        local icon = Util.GetGameObject(o,"icon"):GetComponent("Image")
        local pro = Util.GetGameObject(o,"proIcon"):GetComponent("Image")
        local lv = Util.GetGameObject(o,"lv/Text"):GetComponent("Text")
        local star = Util.GetGameObject(o,"star")
        local choosed = Util.GetGameObject(o,"choosed")
        local hpExp = Util.GetGameObject(o,"hpExp"):GetComponent("Slider")
        frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig[v.tmpId].Quality,v.star))
        icon.sprite = Util.LoadSprite(GetResourcePath(heroConfig[v.tmpId].Icon))
        pro.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig[v.tmpId].PropertyName))
        lv.text = v.level
        SetHeroStars(star, v.star)
        --血量相关
        hpExp.value = v.heroHp/10000
        Util.SetGray(o,v.heroHp <= 0)

        choosed:SetActive(false)
        if MapTrialManager.selectHeroDid == v.heroId then
            choosed:SetActive(true)
            oldChoosed = choosed
            selectHeroDid = v.heroId
        end

        Util.AddOnceClick(o,function()
            if v.heroHp <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11658)
                return
            end
            if oldChoosed then
                if selectHeroDid == v.heroId then
                    return
                end
                oldChoosed:SetActive(false)
            end
            if oldChoosed ~= choosed then
                choosed:SetActive(true)
                oldChoosed = choosed
                selectHeroDid = v.heroId
            end
        end)
    end
end

return this