----- 送神弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local _args = {}
--传入选择英雄计算返回奖励数据列表
local dropList = {}
--item容器
local itemList = {}
--传入选择英雄
local selectHeroData
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText = Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.cancelBtn = Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn = Util.GetGameObject(gameObject,"ConfirmBtn")

    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root/scroll")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        local data = {}
        for k,v in pairs(selectHeroData) do
            table.insert(data,v.dynamicId)
        end
        --卸下作战方案
        for n,m in pairs(data) do
            local hero = HeroManager.GetSingleHeroData(m)
            if hero.planList and #hero.planList > 0 then
                for k,v in ipairs(hero.planList) do
                   local sData = v
                   local bData = CombatPlanManager.GetPlanData(sData.planId)
                   CombatPlanManager.DownPlan(m,bData.id,sData.position, function()
                      CombatPlanManager.DownPlanData(m, sData.planId)
                      --RoleInfoPanel.UpdateEquipPosHeroData(3, 2,bData.id, nil,sData.position + 4)
                   end)
                end
            end
        end
        NetManager.UseAndPriceItemRequest(3, data, function(msg)
            HeroManager.DeleteHeroDatas(data)
            parent:ClosePanel()
            UIManager.OpenPanel(UIName.RewardItemPopup,msg,1,function ()
                ResolvePanel.SwitchView(1)
            end)
        end)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder =_parent.sortingOrder-1
    local args = {...}
    dropList = args[1]
    selectHeroData = args[2]

    this.titleText.text = GetLanguageStrById(11643)
    --返还比
    local num = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,35).Value)/100
    this.bodyText.text = string.format( GetLanguageStrById(11644),num,"%")

    local data = {}
    for i, v in pairs(dropList) do
        data[i] = {v.id,v.num}
    end
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,10,1,sortingOrder,false,data)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this