require("Modules.Battle.Config.PokemonEffectConfig")
require("Base/BasePanel")
local DamageResultPanel = Inherit(BasePanel)
local this = DamageResultPanel

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(91 / 255, 91 / 255, 91 / 255, 1), --m5
                        select = Color.New(82 / 255, 51 / 255, 10 / 255, 1) } --m5
local _TabData = {
    [1] = { default = Color.New(161/255, 161/255, 161/255, 1), select =   Color.New(255/255, 208/255, 43/255, 1), name = GetLanguageStrById(10271) },
    [2] = { default = Color.New(161/255, 161/255, 161/255, 1), select =   Color.New(255/255, 208/255, 43/255, 1),  name = GetLanguageStrById(10272) },} 

-- 最大层数
local _MaxOrder = 0

-- 最大数值，以最大数值为比计算其他数值的比例
local _MaxDamageValue = 0
local _MaxTreatValue = 0

-- 总伤害和治疗数值
local _AllDamageValue = {}
local _AllTreatValue = {}

-- 节点保存
local _LeftItemPool = {}
local _RightItemPool = {}

local LEFT_CAMP = 0
local RIGHT_CAMP = 1

-- 数据重构
local _NormalMonsterList = {}
local _DiffMonsterList = {}

--初始化组件（用于子类重写）
function DamageResultPanel:InitComponent()

    this.BtnBack = Util.GetGameObject(this.transform, "btnBack")
    this.BackMask = Util.GetGameObject(this.transform,"BackMask")

    this.leftName = Util.GetGameObject(this.transform, "left/name"):GetComponent("Text")
    this.leftItem = Util.GetGameObject(this.transform, "left/item")
    this.leftGrid = Util.GetGameObject(this.transform, "left/grid")

    this.rightName = Util.GetGameObject(this.transform, "right/name"):GetComponent("Text")
    this.rightItem = Util.GetGameObject(this.transform, "right/item")
    this.rightGrid = Util.GetGameObject(this.transform, "right/grid")
    
    -- 初始化Tab管理器
    this.tabbox = Util.GetGameObject(this.transform, "top")
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
    
end

--绑定事件（用于子类重写）
function DamageResultPanel:BindEvent()
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function DamageResultPanel:AddListener()
end

--移除事件监听（用于子类重写）
function DamageResultPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function DamageResultPanel:OnOpen(result)

    local nameStr = BattleRecordManager.GetBattleBothNameStr()
    if nameStr then
        local namelist = string.split(nameStr, "|")
        this.leftName.text = namelist[1]
        this.rightName.text = namelist[2]
    else
        this.leftName.text = GetLanguageStrById(10273)
        this.rightName.text = GetLanguageStrById(10274)
    end

    this.battleRecord = BattleRecordManager.GetBattleRecord()

    -- 初始化数据
    _MaxOrder = 0
    _MaxDamageValue = 0
    _MaxTreatValue = 0
    _AllDamageValue = {}
    _AllTreatValue = {}
    _NormalMonsterList = {}
    _DiffMonsterList = {}

    -- 判断最后一层战斗的层数
    for _, data in pairs(this.battleRecord) do
        if data.order > _MaxOrder then
            _MaxOrder = data.order
        end
    end

    -- 数据匹配
    if not this.battleRecord then return end
    for _, data in pairs(this.battleRecord) do
        -- 怪物只显示最后一层的怪物信息
        if data.camp ~= RIGHT_CAMP or data.order == _MaxOrder then
            -- 计算最大值
            if data.damage > _MaxDamageValue then _MaxDamageValue = data.damage end
            if data.heal > _MaxTreatValue then _MaxTreatValue = data.heal end

            -- 计算总值
            if not _AllDamageValue[data.camp] then _AllDamageValue[data.camp] = 0 end
            if not _AllTreatValue[data.camp] then _AllTreatValue[data.camp] = 0 end
            _AllDamageValue[data.camp] = _AllDamageValue[data.camp] + data.damage
            _AllTreatValue[data.camp] = _AllTreatValue[data.camp] + data.heal

            -- 数据重构
            if data.type == 0 then
                table.insert(_NormalMonsterList, data)
            else
                table.insert(_DiffMonsterList, data)
            end
        end
    end

    -- 排序
    table.sort(_NormalMonsterList, function(a, b)
        return a.uid < b.uid
    end)
    table.sort(_DiffMonsterList, function(a, b)
        return a.camp == b.camp and a.type < b.type or a.camp < b.camp
    end)


    -- tab节点管理
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(1)
    end

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DamageResultPanel:OnShow()end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    -- Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    Util.GetGameObject(tab,"Img"):GetComponent("Image").color = _TabData[index][status]
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)

    local showType = index  -- 1 伤害 2 治疗

    -- 关闭显示
    for _, item in pairs(_LeftItemPool) do 
        item:SetActive(false) 
    end
    for _, item in pairs(_RightItemPool) do 
        item:SetActive(false) 
    end

    -- 数据匹配
    if not this.battleRecord then return end
    local leftIndex, rightIndex = 1, 1
    local function CreateMonsterItem(data)
        -- 怪物只显示最后一层的怪物信息
        if data.camp ~= RIGHT_CAMP or data.order == _MaxOrder then
            local pool, item, grid, index
            if data.camp == LEFT_CAMP then
                pool, item, grid, index = _LeftItemPool, this.leftItem, this.leftGrid, leftIndex
                leftIndex = leftIndex + 1
            elseif data.camp == RIGHT_CAMP then
                pool, item, grid, index = _RightItemPool, this.rightItem, this.rightGrid, rightIndex
                rightIndex = rightIndex + 1
            end

            if not pool[index] then
                pool[index] = newObjToParent(item, grid)
            end
            pool[index]:SetActive(true)
            this.ItemAdapter(pool[index], data, showType)
        end
    end

    -- 创建
    for _, data in ipairs(_NormalMonsterList) do
        CreateMonsterItem(data)
    end
    for _, data in ipairs(_DiffMonsterList) do
        CreateMonsterItem(data)
    end

    -- 播放动画
    this.StartPlayAnim(showType)
end

-- 开始播放动画
function this.StartPlayAnim(showType)
    -- 根据showType播放动画
    DoTween.To(
        DG.Tweening.Core.DOGetter_float( function () return 0 end),
        DG.Tweening.Core.DOSetter_float(
            function (progress)
                local leftIndex, rightIndex = 1, 1
                local function _Play(data)
                    -- 怪物只显示最后一层的怪物信息
                    if data.camp ~= RIGHT_CAMP or data.order == _MaxOrder then
                        local pool, index, drt
                        if data.camp == LEFT_CAMP then
                            pool, index = _LeftItemPool, leftIndex
                            leftIndex = leftIndex + 1
                            drt = 1
                        elseif data.camp == RIGHT_CAMP then
                            pool, index = _RightItemPool, rightIndex
                            rightIndex = rightIndex + 1
                            drt = 1
                        end
                        if pool[index] then
                            local _progress = Util.GetGameObject(pool[index], "progress")
                            local value = 0
                            if showType == 1 then
                                if _MaxDamageValue ~= 0 then
                                    value = data.damage/_MaxDamageValue
                                end
                            else
                                if _MaxTreatValue ~= 0 then
                                    value = data.heal/_MaxTreatValue
                                end
                            end
                            _progress.transform.localScale = Vector3(value * progress * drt, 1, 1)
                        end
                    end
                end

                -- 创建
                for _, data in ipairs(_NormalMonsterList) do
                    _Play(data)
                end
                for _, data in ipairs(_DiffMonsterList) do
                    _Play(data)
                end
            end),
        1, 1)
        :SetEase(Ease.OutQuad)
end

-- 数据匹配
function this.ItemAdapter(item, data, showType)
    local damage = Util.GetGameObject(item, "damage"):GetComponent("Text")
    local progress = Util.GetGameObject(item, "progress")
    local head = Util.GetGameObject(item, "headpos/head")
    --头像的名字
   -- local name = Util.GetGameObject(item, "headpos/Name")
    local value = showType == 1 and data.damage or data.heal
    damage.text = math.floor(value)

    --local allValue = showType == 1 and _AllDamageValue[data.camp] or _AllTreatValue[data.camp]
    --local ratio = allValue == 0 and 0 or math.floor(value/allValue*10000)/100
    --damage.text = string.format("%d(%.2f%%)", value, ratio)

    progress.transform.localScale = Vector3(0, 1, 1)
    this.HeadAdapter(head, data)
end

-- 头像数据匹配
function this.HeadAdapter(head, data)
    local frame = Util.GetGameObject(head, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(head, "icon"):GetComponent("Image")
    --头像的名字
    local name = Util.GetGameObject(head, "Name"):GetComponent("Text")
    local proto = Util.GetGameObject(head, "prott")
    local protoImage = Util.GetGameObject(head, "prott"):GetComponent("Image")
    local protoIcon = Util.GetGameObject(head, "prott/Image"):GetComponent("Image")
    local lv = Util.GetGameObject(head, "lv")
    local lvText = Util.GetGameObject(head, "lv/Text"):GetComponent("Text")
    
    --
    local roleId = data.monsterId or data.roleId

    --local roleInfo = BattleManager.GetRoleData(data.type, data.uid)
    if data.type == 0 then
        local config = {}
        if roleId > 10100 then
            local MonsterConfig = ConfigManager.GetConfigData(ConfigName.MonsterConfig, roleId)
            config.Quality = MonsterConfig.Quality
            config.lv = MonsterConfig.Level
            
            if MonsterConfig.MonsterId > 10000 then
                local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, MonsterConfig.MonsterId)
                config.Icon = heroConfig.Icon
                config.Profession = heroConfig.Profession
                config.PropertyName = heroConfig.PropertyName
                --战车名字
                name.text=GetLanguageStrById(heroConfig.ReadingName)
            else
                local monsterViewInfo = ConfigManager.GetConfigData(ConfigName.MonsterViewConfig, MonsterConfig.MonsterId)
                config.Icon = monsterViewInfo.MonsterIcon
                 --战车名字
                name.text=GetLanguageStrById(monsterViewInfo.ReadingName)
            end
        else
            local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, roleId)
            config.Quality = heroConfig.Quality
            config.Icon = heroConfig.Icon
            config.Profession = heroConfig.Profession
            config.PropertyName = heroConfig.PropertyName

            config.lv = data.roleLv
             --战车名字
            name.text=GetLanguageStrById(heroConfig.ReadingName)
        end

        frame.sprite = Util.LoadSprite(GetQuantityImageByquality(config.Quality))
        icon.sprite = Util.LoadSprite(GetResourcePath(config.Icon))
        protoImage.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(config.Quality))

        lv:SetActive(true)
        lvText.text = config.lv

        proto:SetActive(false)
        if config.PropertyName then
            protoIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(config.PropertyName))
            proto:SetActive(true)
        end

    else
        proto:SetActive(false)
        lv:SetActive(false)

        frame.sprite = Util.LoadSprite("r_zhandou_yiyaodi")
        local iconName = PokemonEffectConfig[data.type].icon
        icon:GetComponent("Image").sprite = Util.LoadSprite(iconName)
    end

end


--界面关闭时调用（用于子类重写）
function DamageResultPanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function DamageResultPanel:OnDestroy()
    _LeftItemPool = {}
    _RightItemPool = {}

    _MaxDamageValue = 0
    _MaxTreatValue = 0
end

return DamageResultPanel