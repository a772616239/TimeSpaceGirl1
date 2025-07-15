local this = {}
local proId = 1--0全部 1机械 2体能 3魔法 4秩序 5混沌 6
local tabs = {}
local moveIndex = 0
local moveV2 = 0
local handbooklevel = 1

--初始化组件（用于子类重写）
function this:InitComponent(root)
    self.gameObject = root

    self.Button_Base = Util.GetGameObject(self.gameObject, "bg/Button_Base")
    self.Button_Base_Select = Util.GetGameObject(self.gameObject, "bg/Button_Base/select")
    self.Button_Senior = Util.GetGameObject(self.gameObject, "bg/Button_Senior")
    self.Button_Senior_Select = Util.GetGameObject(self.gameObject, "bg/Button_Senior/select")

    self.getAllbtn = Util.GetGameObject(self.gameObject,"btnBg/getAllbtn")

    --英雄
    self.heroScroll = Util.GetGameObject(self.gameObject, "heroScroll")
    self.heroScrollbar = Util.GetGameObject(self.gameObject, "heroScrollbar")
    self.card = poolManager:LoadAsset("card", PoolManager.AssetType.GameObject) 
    self.card.transform:SetParent(self.gameObject.transform)
    self.card:GetComponent("RectTransform").localScale = Vector3.New(1,1,1)
    self.card:SetActive(false)

    for i = 0, 5 do
        tabs[i] = Util.GetGameObject(self.gameObject, "Tabs/grid/Btn" .. i)
        Util.GetGameObject(tabs[i], "redPoint"):SetActive(false)
    end

    local v2 = self.heroScroll:GetComponent("RectTransform").rect
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.heroScroll.transform,self.card, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 4, Vector2.New(-5,-5))
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）·
function this:BindEvent()
    for i = 0, 5 do
        Util.AddClick(tabs[i], function()
            proId = i
            self:OnShowHeroFun()
        end)
    end
    Util.AddClick(self.getAllbtn,function()
        NetManager.GetHandBookListHero(proId,function(msg)
            NetManager.PlayerInfoRequest(function()
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1)
                this:OnShowHeroFun()
                Game.GlobalEvent:DispatchEvent(GameEvent.HandBook.RefreshRedPoint)
            end)
        end)
    end)

    Util.AddClick(self.Button_Base,function()
        if handbooklevel ~= 1 then
            handbooklevel = 1
            this:OnShowHeroFun()
        end
    end)

    Util.AddClick(self.Button_Senior,function()
        if handbooklevel ~= 2 then
            handbooklevel = 2
            this:OnShowHeroFun()
        end
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

--界面打开时调用（用于子类重写）
function this:OnOpen(_type)
    OpenType = _type
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
    self.heroScroll:SetActive(true)
    -- NetManager.PlayerInfoRequest(function()
    --     self:OnShowHeroFun()
    -- end)
    self:OnShowHeroFun()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

function this:OnSortingOrderChange(sortingOrder)
    self.sortingOrder = sortingOrder
end

--英雄展示
function this:OnShowHeroFun()
    self:SetSelectBtn()

    self:SetTabRedPointStatus()

    self.Button_Base_Select:SetActive(handbooklevel == 1)
    self.Button_Senior_Select:SetActive(handbooklevel == 2)

    local data = self:GetHeroData()

    self.getAllbtn:SetActive(false)
    if proId ~= 0 then
        for key, value in pairs(data) do
            local heroId = value.heroConfig.Id
            if PlayerManager.heroHandBook[heroId] then
                if PlayerManager.heroHandBook[heroId].status == 0 then
                    self.getAllbtn:SetActive(true)
                end
            end
        end
    end

    self.ScrollView:SetData(data, function(dataIndex, go) 
        self:showData(go,data[dataIndex])
    end,1)
    if moveIndex ~= 0 and moveV2 ~= 0 then
        self.ScrollView:SetOffset(moveIndex,moveV2)
    end
end

--设置按钮红点
function this:SetTabRedPointStatus()
    local redPonitHeroDatas = {}
    local v = proId
    for i = 0, 5 do
        proId = i
        redPonitHeroDatas[i] = self:GetHeroData()
        Util.GetGameObject(tabs[i], "redPoint"):SetActive(false)
    end
    proId = v
    for redPointIndex = 0, 5 do
        for Rindex, Rvalue in ipairs(redPonitHeroDatas[redPointIndex]) do
            local heroId = Rvalue.heroConfig.Id
            if PlayerManager.heroHandBook[heroId] then
                if PlayerManager.heroHandBook[heroId].status == 0 then
                    Util.GetGameObject(tabs[redPointIndex], "redPoint"):SetActive(true)
                end
            end
        end
    end
end

--设置选中按钮
function this:SetSelectBtn()
    for key, value in pairs(tabs) do
        value:GetComponent("Image").sprite = Util.LoadSprite(X1CampTabSelectPic[key])
        Util.GetGameObject(value.transform, "Image"):SetActive(key == proId)
    end
end

--获取英雄数据
function this:GetHeroData()
    local herodatas = {}
    for id, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroConfig)) do      
        if v.AfkUse == 1 or v.AfkUse == 3 then--所属等于0的不显示
            if proId == 0 or proId == v.PropertyName then
                -- if v.MaxRank >= 10 then 
                --     --上限星级大于等于10的是必须加的
                --     table.insert(heroScniorDatas,{heroConfig = v,star = 10})
                -- else if v.MaxRank >= 6 and v.Star < 10 then
                --     --上限星级大于等于6的 初始星级小于10添加
                --     table.insert(heroScniorDatas,{heroConfig = v,star = 6})
                -- else
                --     table.insert(heroScniorDatas,{heroConfig = v,star = v.Star})
                -- end
                if handbooklevel == 1 then
                    table.insert(herodatas,{heroConfig = v,star = v.Star})
                else
                    table.insert(herodatas,{heroConfig = v,star = v.MaxRank})
                end

            end
        end
    end
    self:SortHero(herodatas)
    PlayerManager.heroHandBookListData = herodatas
    return herodatas
end

--对英雄列表排序
function this:SortHero(heroList)
    table.sort(heroList, function(a, b)
        if a.star == b.star then
            if a.heroConfig.Natural == b.heroConfig.Natural then
                if a.heroConfig.HeroValue == 1 and b.heroConfig.HeroValue == 1 then
                    return a.heroConfig.Id < b.heroConfig.Id
                else
                    return a.heroConfig.HeroValue > b.heroConfig.HeroValue
                end
                -- return a.heroConfig.Id < b.heroConfig.Id
            else
                return a.heroConfig.Natural > b.heroConfig.Natural
            end
        else
            return a.star > b.star
        end
    end)
end

--设置英雄数据
function this:showData(go, data)
    local heroMaxConfig = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", data.heroConfig.Star, "OpenStar", data.star)
    local card = Util.GetGameObject(go.transform, "card")
    local bg = Util.GetGameObject(card, "bg"):GetComponent("Image")
    local icon =  Util.GetGameObject(card, "icon"):GetComponent("Image")
    local frame = Util.GetGameObject(card, "frame")
    local pro = Util.GetGameObject(card, "pro/Image"):GetComponent("Image")
    local lv = Util.GetGameObject(card, "lv"):GetComponent("Text")
    local star = Util.GetGameObject(card, "star")
    local redPoint = Util.GetGameObject(card, "sign/redPoint")
    local core = Util.GetGameObject(card, "sign/core")

    local level
    if handbooklevel == 1 then--基础
        level = 1
    elseif handbooklevel == 2 then--高级
        level = heroMaxConfig[#heroMaxConfig].OpenLevel
    end

    lv.text = level
    icon.sprite = Util.LoadSprite(GetResourcePath(data.heroConfig.Painting))
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(data.heroConfig.PropertyName))

    SetHeroStars(star, data.star)
    SetHeroBg(bg, frame, data.heroConfig.Quality, data.star)

    core:SetActive(data.heroConfig.HeroValue == 1)

    Util.AddOnceClick(card, function()
        UIManager.OpenPanel(UIName.HandBookHeroInfoPanel, data, proId, handbooklevel)
    end)

    --设置红点情况
    if PlayerManager.heroHandBook[data.heroConfig.Id] ~= nil then
        if PlayerManager.heroHandBook[data.heroConfig.Id].status == 1 then
            redPoint:SetActive(false)
        else
            redPoint:SetActive(true)
        end
    else
        redPoint:SetActive(false)
    end

    if PlayerManager.heroHandBook and PlayerManager.heroHandBook[data.heroConfig.Id] then
        Util.SetGray(icon.gameObject, false)
        Util.SetGray(pro.gameObject, false)
        Util.SetGray(bg.gameObject, false)
    else
        Util.SetGray(icon.gameObject, true)
        Util.SetGray(pro.gameObject, true)
        Util.SetGray(bg.gameObject, true)
    end
end

return this