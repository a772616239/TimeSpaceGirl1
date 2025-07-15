----- 归元弹窗 -----
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
--传入选择英雄
local selectHeroData
--消耗道具
local costData = {}
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local func

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject, "TitleText"):GetComponent("Text")
    this.bodyText = Util.GetGameObject(gameObject, "BodyText"):GetComponent("Text")
    this.cancelBtn = Util.GetGameObject(gameObject, "CancelBtn")
    this.confirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.costText = Util.GetGameObject(gameObject, "costText"):GetComponent("Text")
    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root/Viewport/Content")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        local data
        for k,v in pairs(selectHeroData) do
            data = v.dynamicId
            break
        end
        NetManager.HeroRetureEvent(data, function(msg)
            HeroManager.ResetHero(data)
            local hero = HeroManager.GetSingleHeroData(data)

            -- --卸下作战方案
            -- if hero.planList and #hero.planList > 0 then
            --     for k,v in ipairs(hero.planList)  do
            --         local sData = v
            --         if sData.position == 1 then --六星解锁作战方案不用卸下
            --             local bData = CombatPlanManager.GetPlanData(sData.planId)
            --             CombatPlanManager.DownPlan(data, bData.id, sData.position, function()
            --                RoleInfoPanel.UpdateEquipPosHeroData(3, 2, bData.id, nil, sData.position + 4)
            --              end)
            --         end
            --     end
            --  end

            --卸载装备
            if hero.equipIdList then
                for i = 1, #hero.equipIdList do
                    EquipManager.DeleteSingleEquip(hero.equipIdList[i], hero.dynamicId)
                end
            end
            hero.equipIdList = {}
            HeroManager.SetHeroEquipIdList(hero.dynamicId, {})
            hero.equipIdList = {}
    
            --卸载戒指
            for i = 1, 2 do
                local planList=hero.planList[1]
                if planList then
                    local planDid=planList.planId
                    if planDid then
                        table.remove(hero.planList,1)
                        CombatPlanManager.DownPlanData(hero.dynamicId, planDid)
                    end
                end
            end
            
            
            --卸载芯片
            for k,v in pairs(MedalManager.allMedal)  do
                if hero.dynamicId==v.upHeroDid then
                    local curHeroData = HeroManager.GetSingleHeroData(v.upHeroDid)
                    MedalManager.allMedal[k].upHeroDid = nil
                    if curHeroData and curHeroData.medal then 
                        for _,j in pairs(curHeroData.medal) do
                            if j and j.id==k then
                                table.removebyvalue(curHeroData.medal,j)
                                -- break
                            end
                        end
                    end
                end
     
            end



            PopupTipPanel.ShowTip(GetLanguageStrById(12276))
            parent:ClosePanel()
            RoleInfoPanel:UpdatePanelData()
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
            end,0,nil,nil,1)
            if func then
                func()
            end
        end)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    dropList = args[1]
    selectHeroData = args[2]
    costData = args[3]
    func = args[4]
    this.root.transform:GetComponent("RectTransform"):DOAnchorPosX(0, 0)

    this.titleText.text = GetLanguageStrById(11645)

    if costData ~= nil then
        local lv
        for k, v in pairs(selectHeroData) do
            lv = v.lv
            break
        end
        if lv <= 100 then
            this.costText.text = string.format(GetLanguageStrById(50225), 100)
        else
            this.costText.text = string.format("%s%s%s",GetLanguageStrById(23162),costData[1][2],GetLanguageStrById(itemConfig[costData[1][1]].Name))
        end
    else
        this.costText.text = ""
    end
    --返还比
    local num = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,34).Value)/100
    this.bodyText.text = GetLanguageStrById(11646)--string.format(GetLanguageStrById(11646), num, "%")

    local _data = {}
    for i = 1,#dropList do
        _data[i] = {dropList[i].id,dropList[i].num,nil,dropList[i].star}
    end
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,8,1,sortingOrder,false,_data)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this