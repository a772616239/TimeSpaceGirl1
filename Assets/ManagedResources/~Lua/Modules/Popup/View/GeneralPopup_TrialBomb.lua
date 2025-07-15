----- 异端之战炸弹 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local ctrlView = require("Modules/Map/View/MapControllView")
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local trialSetting = ConfigManager.GetConfig(ConfigName.TrialSetting)
local trialConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)
local item
local itemId = 0 --消耗道具ID
local itemNum = 0 --消耗道具数量
local usedNum = 0 --已使用的数量

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.body = Util.GetGameObject(gameObject,"Body")
    this.item = Util.GetGameObject(this.body,"Item")
    this.desc = Util.GetGameObject(this.body,"Root"):GetComponent("Text")
    this.leftTime = Util.GetGameObject(this.body,"leftTime"):GetComponent("Text")
    this.num = Util.GetGameObject(this.body,"Num"):GetComponent("Text")
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
        if itemNum > 0 then
            if trialSetting[1].PrivilegeReward[2]-MapTrialManager.bombUsed <= 0 then
                PopupTipPanel.ShowTip(GetLanguageStrById(11651))
                return
            end
            -- if true then
            --     return
            -- end
            if MapTrialManager.isHaveBoss then
                PopupTipPanel.ShowTipByLanguageId(11248)
                return
            elseif MapTrialManager.curTowerLevel>10000 then
                PopupTipPanel.ShowTipByLanguageId(12379)
                return
            else
                NetManager.RequestUseBomb(function (msg)--请求使用炸弹
                    parent:ClosePanel()
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function()
                        MapTrialManager.UpdatePowerValue(msg.essenceValue)
                        MapTrialManager.SetKillCount(msg.trialKillCount) 
                        Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointAdd, msg.cell.cellId, msg.cell.pointId)
                    end)
                    MapTrialManager.isHaveBoss = true
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(11249)
        end
    end)
end

-- 弄死所有的小怪
function this:KillAllBitch()
    --杀死所有的小怪
    MapManager.isRemoving = true
    local pointData = trialConfig[MapTrialManager.curTowerLevel].MonsterPoint --MonsterPoint
    for i = 1, #pointData do
        local mapPointId = pointData[i][1]
        if mapPointId then
            MapManager.DeletePos(mapPointId)
        end
    end
    MapManager.isRemoving = false
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.RefreshPanel)--监听背包信息改变刷新 用于回春散数量刷新
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.RefreshPanel)
end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local _args = {...}
    this.titleText.text = GetLanguageStrById(12702)
    this.desc.text = GetLanguageStrById(12703)
    itemId = trialSetting[1].BombId[1][1]
    itemNum = BagManager.GetItemCountById(itemId)
    usedNum = MapTrialManager.bombUsed
    this.RefreshPanel()
end

function this:OnClose()
end

function this:OnDestroy()
    item = nil
end

--刷新面板
function this.RefreshPanel()
    item:OnOpen(false, {itemId,1}, 1.2,false,false,false,sortingOrder)
    item:Reset({itemId,1},ItemType.NoType,{nil,false,nil,false})
    this.num.text = GetLanguageStrById(11657)..itemNum
    this.leftTime.text = GetLanguageStrById(11656)..trialSetting[1].PrivilegeReward[2]-usedNum
end

return this