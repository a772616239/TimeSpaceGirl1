require("Base/BasePanel")
BuffPreviewPopup = Inherit(BasePanel)
local this = BuffPreviewPopup
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local InvestigateConfig = ConfigManager.GetConfig(ConfigName.InvestigateConfig)
local DefTrainingBuff = ConfigManager.GetConfig(ConfigName.DefTrainingBuff)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)

-- local _tabIdx = 1
-- local TabBox = require("Modules/Common/TabBox")
-- local _TabData = {
--     [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(22619) },
--     [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(22620) },
--     [3] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name = GetLanguageStrById(22621) }
-- }

--初始化组件（用于子类重写）
function this:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")

    this.LeftHead = Util.GetGameObject(self.gameObject,"bg/Up/LeftHead")
    this.leftPlayerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.LeftHead.transform)
    this.LeftName = Util.GetGameObject(self.gameObject,"bg/Up/LeftName"):GetComponent("Text")

    this.RightHead = Util.GetGameObject(self.gameObject,"bg/Up/RightHead")
    this.rightPlayerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.RightHead.transform)
    this.RightName = Util.GetGameObject(self.gameObject,"bg/Up/RightName"):GetComponent("Text")

    -- this.ItemPre = Util.GetGameObject(self.gameObject,"bg/ItemPre")
    -- this.Left = Util.GetGameObject(self.gameObject,"bg/Left")
    -- this.Right = Util.GetGameObject(self.gameObject,"bg/Right")

    --buff预览
    -- this.buffPreview = Util.GetGameObject(self.gameObject,"buff")
    -- this.buffPre = Util.GetGameObject(this.buffPreview.gameObject,"buffPre")
    -- this.tabBox = Util.GetGameObject(this.buffPreview.gameObject,"TabBox")
    -- this.scroll = Util.GetGameObject(this.buffPreview.gameObject,"Scroll")
    -- local rect = this.scroll.transform.rect
    -- this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform, this.buffPre, nil,
    -- Vector2.New(rect.width, rect.height), 1, 1, Vector2.New(5, 5))
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    -- this.scrollView.moveTween.MomentumAmount = 1
    -- this.scrollView.moveTween.Strength = 2

    this.proPrefab = Util.GetGameObject(self.gameObject, "proPrefab")
    this.buffPrefab = Util.GetGameObject(self.gameObject, "buffPrefab")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    -- Util.AddClick(this.buffPreview, function()
    --     this.buffPreview:SetActive(false)
    --     this.selectRole = nil
    --     this.buffData = {}
    -- end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener() 
end


--界面打开时调用（用于子类重写）
function this:OnOpen(roles)
    this.roles = roles

    local function CloseSelf()
        -- LogError("close!!!")
        self:ClosePanel()
    end

    BattleLogic.Event:AddEvent(BattleEventName.BeforeBattleEnd, CloseSelf)
    -- this.tabCtrl = TabBox.New()
    -- this.tabCtrl:SetTabAdapter(this.TabAdapter) 
    -- this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    -- this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)
    -- this.tabCtrl:Init(this.tabBox, _TabData)
end

-- function BuffPreviewPopup.OnTabIsLockCheck(index)
-- end
-- function BuffPreviewPopup.OnChangeTab(index, lastIndex)
-- end
-- function BuffPreviewPopup.ChangeTab(index)
--     -- this.buffData = this:GetBuffData()
--     -- this:RefreshScroll()
-- end

-- function this:GetBuffData()
--     if not this.selectRole then
--         return nil
--     end
--     local tempData = {}

--     if _tabIdx == 1 then
--         tempData = this.selectRole.BuffList
--     elseif _tabIdx == 2 then
--         for i = 1, #this.selectRole.BuffList do
--             if this.selectRole.BuffList[i].Buff.changeType == 1 or this.selectRole.BuffList[i].Buff.changeType == 2 then
--                 table.insert(tempData,this.selectRole.BuffList[i])
--             else
--             end
--         end
--     elseif _tabIdx == 3 then
--         for i = 1, #this.selectRole.BuffList do
--             if this.selectRole.BuffList[i].Buff.changeType == 1 or this.selectRole.BuffList[i].Buff.changeType == 2 then
--             else
--                 table.insert(tempData,this.selectRole.BuffList[i])
--             end
--         end
--     end
--     return tempData
-- end

-- function BuffPreviewPopup:RefreshScroll()
--     this.scrollView:SetData(this.buffData, function(index, root)
--         self:FillItem(root, this.buffData[index])
--     end)
-- end

-- -- tab节点显示自定义
-- function BuffPreviewPopup.TabAdapter(tab, index, status)
--     Util.GetGameObject(tab, "default/Text"):GetComponent("Text").text = _TabData[index].name
--     Util.GetGameObject(tab, "select/Text"):GetComponent("Text").text = _TabData[index].name

--     local default = Util.GetGameObject(tab,"default")
--     default:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].default)

--     local select = Util.GetGameObject(tab, "select")
--     select:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].select)

--     default:SetActive(status == "default")
--     select:SetActive(status == "select")

--     _tabIdx = index
-- end

-- function BuffPreviewPopup:FillItem(go, data)
--     local buffConfig = data.Config

--     if data.Buff.changeType == 1 or data.Buff.changeType == 2 then
--         Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(buffConfig.Icon))
--     else
--         Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(buffConfig.DIcon))
--     end
--     -- Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(buffConfig.Icon))
--     -- Util.GetGameObject(go, "Name"):GetComponent("Text").text = buffConfig
--     -- Util.GetGameObject(go, "dec"):GetComponent("Text").text = buffConfig.Describe
-- end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
    this.LeftName.text = BattleManager.structA.name
    this.leftPlayerHead:SetScale(Vector3.one * 0.55)
    if type(BattleManager.structA.head) == "number" then
        this.leftPlayerHead:SetHead(BattleManager.structA.head)
    elseif type(BattleManager.structA.head) == "string" then
        this.leftPlayerHead:SetHead(nil, BattleManager.structA.head)
    end
    this.leftPlayerHead:SetHead(BattleManager.structA.head)
    this.leftPlayerHead:SetFrame(BattleManager.structA.headFrame)

    this.RightName.text = BattleManager.structB.name
    this.rightPlayerHead:SetScale(Vector3.one * 0.55)
    if type(BattleManager.structB.head) == "number" then
        this.rightPlayerHead:SetHead(BattleManager.structB.head)
    elseif type(BattleManager.structB.head) == "string" then
        this.rightPlayerHead:SetHead(nil, BattleManager.structB.head)
    end
    this.rightPlayerHead:SetFrame(BattleManager.structB.headFrame)

    -- for i = 1, 5 do
    --     local go = newObject(this.ItemPre)
    --     go.transform:SetParent(this.Left.transform)
    --     go.transform.localScale = Vector3.one
    --     go.transform.localPosition = Vector3.zero
    -- end

    -- for i = 1, 5 do
    --     local go = newObject(this.ItemPre)
    --     go.transform:SetParent(this.Right.transform)
    --     go.transform.localScale = Vector3.one
    --     go.transform.localPosition = Vector3.zero
    -- end

    -- if #BattleManager.elements > 0 then
    --     SetFormationBuffIcon(Image0, BattleManager.elements[0])
    --     SetFormationBuffIcon(Image1, BattleManager.elements[1])
    -- end
    
    -- BattleManager.structA.investigateLevel
    -- BattleManager.structB.investigateLevel
    this.SetBuff()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    -- LogError("closed!!!!!!!")
    -- BattleLogic.Event:RemoveEvent(BattleEventName.BeforeBattleEnd, CloseSelf)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    -- this.selectRole = nil
    -- this.buffData = {}
end

function this.SetBuff()
    for i = 1, 2 do
        local grid = Util.GetGameObject(this.gameObject, "add" .. i)
        Util.ClearChild(grid.transform)

        --阵容加成
        local iconStr, numArray, isGray = FormationManager.GetElementPicNum(BattleManager.elements[i - 1])
        if not isGray then
            local go = this.GetGo(this.buffPrefab, grid)
            this.SetLineup(go, BattleManager.elements[i - 1])
        end

        --启明星科技加成
        local investigateLevel
        if i == 1 then
            investigateLevel = BattleManager.structA.investigateLevel
        elseif i == 2 then
            investigateLevel = BattleManager.structB.investigateLevel
        end
        if investigateLevel > 0 then
            local go = this.GetGo(this.buffPrefab, grid)
            this.SetInvestigate(go, investigateLevel)
        end

        --深渊试炼
        if i == 1 then
            if BattleManager.battleType == BATTLE_TYPE.DefenseTraining then
                if DefenseTrainingManager.curBuffId and DefenseTrainingManager.curBuffId > 0 then
                    local go = this.GetGo(this.buffPrefab, grid)
                    local data = DefTrainingBuff[DefenseTrainingManager.curBuffId]
                    this.SetAbyssTrial(go, data)
                end
            end
        end
    end
end

function this.GetGo(pre, grid)
    local go = newObject(pre)
    go.transform:SetParent(grid.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero

    return go
end

--设置阵容加成
function this.SetLineup(go, elementsId)
    Util.GetGameObject(go, "title/name"):GetComponent("Text").text = GetLanguageStrById(50179)--阵容加成
    local lineup = Util.GetGameObject(go, "title/lineup")
    lineup:SetActive(true)
    SetFormationBuffIcon(lineup, elementsId)

    local buffGrid = Util.GetGameObject(go, "buffGrid")
    local allElementData = FormationManager.GetOpenElement(elementsId)
    for i, v in ipairs(allElementData) do
        for _, data in ipairs(v) do
            if data.isOpen then
                for i = 1, #data.configData.BuffValue do
                    local go = this.GetGo(this.proPrefab, buffGrid)
                    this.SetProPre(go, data.configData.BuffValue[i])
                end
            end
        end
    end
end

--设置启明星加成
function this.SetInvestigate(go, level)
    local config = InvestigateConfig[level]
    Util.GetGameObject(go, "title/name"):GetComponent("Text").text = GetLanguageStrById(50180) .. "Lv.<color=#ffd12b> " .. level .. "</color>"
    local investigateCenter = Util.GetGameObject(go, "title/investigateCenter")
    investigateCenter:SetActive(true)
    investigateCenter:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.ArtResourcesId))
    SetHeroStars(Util.GetGameObject(investigateCenter, "star"), level)

    local buffGrid = Util.GetGameObject(go, "buffGrid")
    for i = 1, #config.PropertyAdd do
        local go = this.GetGo(this.proPrefab, buffGrid)
        this.SetProPre(go, config.PropertyAdd[i])
    end
end

--设置深渊试炼
function this.SetAbyssTrial(go, data)
    Util.GetGameObject(go, "title/abyssTrial"):SetActive(true)
    Util.GetGameObject(go, "title/name"):GetComponent("Text").text = GetLanguageStrById(50212)
    Util.GetGameObject(go, "abyssTrial"):SetActive(true)
    Util.GetGameObject(go, "abyssTrial/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(PassiveSkillConfig[data.PassiveSkillId].Icon))
    Util.GetGameObject(go, "abyssTrial/effect"):GetComponent("Text").text = GetLanguageStrById(PassiveSkillConfig[data.PassiveSkillId].Name)
    Util.GetGameObject(go, "abyssTrial/Text"):GetComponent("Text").text = GetLanguageStrById(PassiveSkillConfig[data.PassiveSkillId].Desc)
end

--设置属性
function this.SetProPre(go, data)
    local config = PropertyConfig[data[1]]
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(config.Icon)
    Util.GetGameObject(go, "name"):GetComponent("Text").text = GetLanguageStrById(config.Info)
    if config.Style == 1 then
        Util.GetGameObject(go, "value"):GetComponent("Text").text = "+" .. data[2]
    else
        Util.GetGameObject(go, "value"):GetComponent("Text").text = "+" .. data[2]/100 .. "%"
    end
end

-- function this:Update()
--     local leftIndex,rightIndex = 1,1
--     local leftList = {}
--     local rightList = {}
--     for r, v in pairs(this.roles) do
--         if not v.isDead then
--             if r.camp == 0 then
--                 table.insert(leftList,v)
--                 -- leftList[leftIndex] = v
--                 -- leftIndex = leftIndex+1
--             else
--                 -- rightList[rightIndex] =v
--                 -- rightIndex = rightIndex+1
--                 table.insert(rightList,v)
--             end
--         else
--         end
--     end

--     if #leftList > 0 and #rightList > 0 then
--         for i = 1, this.Left.transform.childCount do
--             local go = this.Left.transform:GetChild(i-1).gameObject
--             if i > #leftList then
--                 go:SetActive(false)
--             else
--                 go:SetActive(true)
--                 this:SetItemInfo(go,leftList[i])
--             end
--         end

--         for i = 1, this.Right.transform.childCount do
--             local go = this.Right.transform:GetChild(i-1).gameObject
--             if i > #rightList then
--                 go:SetActive(false)
--             else
--                 go:SetActive(true)
--                 this:SetItemInfo(go,rightList[i])
--             end
--         end
--     else
--         self:ClosePanel()
--     end

--     -- if this.selectRole then
--     --     this.buffData = this:GetBuffData()
--     --     BuffPreviewPopup:RefreshScroll()
--     -- end
-- end


-- function this:SetItemInfo(go, role)
--     local _data = role.role

--     local head = Util.GetGameObject(go, "head")

--     -- Util.AddClick(head, function()
--     --     this.selectRole = role
--     --     this.buffPreview:SetActive(true)
--     --     _tabIdx = 1
--     --     this.ChangeTab(_tabIdx)
--     -- end)

--     local frame = Util.GetGameObject(head, "frame"):GetComponent("Image")
--     local icon = Util.GetGameObject(head, "icon"):GetComponent("Image")
--     --头像的名字
--     --local name = Util.GetGameObject(head, "Name"):GetComponent("Text")
--     local proto = Util.GetGameObject(head, "prott")
--     local protoImage = Util.GetGameObject(head, "prott"):GetComponent("Image")
--     local protoIcon = Util.GetGameObject(head, "prott/Image"):GetComponent("Image")
--     local lv = Util.GetGameObject(head, "lv")
--     local lvText = Util.GetGameObject(head, "lv/Text"):GetComponent("Text")

--     local config = {}
--     if _data.roleId > 10100 then
--         local MonsterConfig = ConfigManager.GetConfigData(ConfigName.MonsterConfig, _data.roleId)
--         config.Quality = MonsterConfig.Quality
--         --config.lv = MonsterConfig.Level
        
--         if MonsterConfig.MonsterId > 10000 then
--             local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, MonsterConfig.MonsterId)
--             config.Icon = heroConfig.Icon
--             config.Profession = heroConfig.Profession
--             config.PropertyName = heroConfig.PropertyName
--             --战车名字
--             --name.text = GetLanguageStrById(heroConfig.ReadingName)
--         else
--             local monsterViewInfo = ConfigManager.GetConfigData(ConfigName.MonsterViewConfig, MonsterConfig.MonsterId)
--             config.Icon = monsterViewInfo.MonsterIcon
--              --战车名字
--             --name.text = monsterViewInfo.ReadingName
--         end
--     else
--         local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, _data.roleId)
--         config.Quality = heroConfig.Quality
--         config.Icon = heroConfig.Icon
--         config.Profession = heroConfig.Profession
--         config.PropertyName = heroConfig.PropertyName

--         --config.lv = _data.roleLv
--         --战车名字
--         --name.text = GetLanguageStrById(heroConfig.ReadingName)
--     end

--     frame.sprite = Util.LoadSprite(GetQuantityImageByquality(config.Quality))
--     icon.sprite = Util.LoadSprite(GetResourcePath(config.Icon))
--     protoImage.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(config.Quality))

--     lv:SetActive(true)
--     lvText.text = _data:GetRoleData(RoleDataName.Level)

--     proto:SetActive(false)
--     if config.PropertyName then
--         protoIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(config.PropertyName))
--         proto:SetActive(true)
--     end


--     local BuffGroup = Util.GetGameObject(go, "BuffGroup")
--     for i = 1, BuffGroup.transform.childCount do
--         local Buff = BuffGroup.transform:GetChild(i-1)
--         local BuffFarme = Util.GetGameObject(Buff, "BuffFarme")

--         if i > #role.BuffList then
--             BuffFarme:SetActive(false)
--             Buff:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_buff_buffkong")
--         else
--             BuffFarme:SetActive(true)
--             if role.BuffList[i].Buff.type == BuffName.PropertyChange  then
--                 if role.BuffList[i].Buff.changeType == 1 or role.BuffList[i].Buff.changeType == 2 then
--                     if role.BuffList[i].Config.Icon then
--                         Buff:GetComponent("Image").sprite = Util.LoadSprite(role.BuffList[i].Config.Icon)
--                     else
--                         Buff:GetComponent("Image").sprite = nil
--                     end
--                 else
--                     if role.BuffList[i].Config.Icon then
--                         Buff:GetComponent("Image").sprite = Util.LoadSprite(role.BuffList[i].Config.Icon)
--                     else
--                         Buff:GetComponent("Image").sprite = nil
--                     end
--                 end
--             else
--                 if role.BuffList[i].Config.Icon then
--                     Buff:GetComponent("Image").sprite = Util.LoadSprite(role.BuffList[i].Config.Icon)
--                 else
--                     Buff:GetComponent("Image").sprite = nil
--                 end
--             end
--         end
--     end
-- end

return BuffPreviewPopup