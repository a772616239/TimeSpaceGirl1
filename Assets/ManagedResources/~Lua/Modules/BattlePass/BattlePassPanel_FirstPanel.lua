local this = {}
local battlePassConfig = ConfigManager.GetConfig(ConfigName.BattlePassConfig)

local tabBtnBg = {
    [1] = { default = "cn2-X1_shouzha_yeqian_01" ,select = "cn2-X1_shouzha_yeqianxuanzhong_01" ,title = GetPictureFont("cn2-X1_shouzha_rumen")},
    [2] = { default = "cn2-X1_shouzha_yeqian_02" ,select = "cn2-X1_shouzha_yeqianxuanzhong_02" ,title = GetPictureFont("cn2-X1_shouzha_zhongji")},
    [3] = { default = "cn2-X1_shouzha_yeqian_03" ,select = "cn2-X1_shouzha_yeqianxuanzhong_03" ,title = GetPictureFont("cn2-X1_shouzha_gaoji")},
    [4] = { default = "cn2-X1_shouzha_yeqian_04" ,select = "cn2-X1_shouzha_yeqianxuanzhong_04" ,title = GetPictureFont("cn2-X1_shouzha_teji")},
}
--按钮类型
local BtnType = {
    Left = 1,
    Right = 2,
}
--当前选中阵容索引
local curIndex = 1

function this:InitComponent(gameObject)
    this.panel = Util.GetGameObject(gameObject, "BattlePassPanel_FirstPanel")

    this.scene = Util.GetGameObject(this.panel, "bg/scene")
    this.mask = Util.GetGameObject(this.scene, "mask")
    this.leftBtn = Util.GetGameObject(this.scene, "leftBtn")
    this.rightBtn = Util.GetGameObject(this.scene, "rightBtn")

    --英雄站位点
    this.points = {}
    local points = Util.GetGameObject(this.scene, "points")
    for i = 1, 9 do
        this.points[i] = Util.GetGameObject(points, "p" .. i)
    end

    this.down = Util.GetGameObject(this.panel, "bg/down")
    this.battleArray = Util.GetGameObject(this.down, "battleArray")--阵容
    this.title = Util.GetGameObject(this.battleArray, "title"):GetComponent("Image")
    this.detailsBtn = Util.GetGameObject(this.battleArray, "detailsBtn")--阵容详情

    --阵容
    this.heros = {}
    this.heroGrid = Util.GetGameObject(this.battleArray, "heroGrid")
    for i = 1, 5 do
        this.heros[i] = Util.GetGameObject(this.heroGrid, "heroItem" .. i)
    end

    --tab
    this.tabs = {}
    this.tabBox = Util.GetGameObject(this.battleArray, "tabBox")
    for i = 1, 4 do
        this.tabs[i] = Util.GetGameObject(this.tabBox, "tab" .. i)
    end

    this.btns = {}
    this.nameBtn = Util.GetGameObject(this.down, "btns/nameBtn")--英雄名称
    this.locationBtn = Util.GetGameObject(this.down, "btns/locationBtn")--英雄定位
    table.insert(this.btns,this.nameBtn)
    table.insert(this.btns,this.locationBtn)

    --获得英雄
    this.getBtn = Util.GetGameObject(this.down, "getBtn")
    this.taskText = Util.GetGameObject(this.getBtn, "value"):GetComponent("Text")
    this.getBtnRedPoint = Util.GetGameObject(this.getBtn, "redPoint")

    --阵容详情
    this.battleArrayDetails = Util.GetGameObject(this.panel, "battleArrayDetails")
    this.detailsText = Util.GetGameObject(this.battleArrayDetails, "Text"):GetComponent("Text")
end

function this:BindEvent()
    Util.AddClick(this.getBtn, function()
        this.battlePanel.SwitchView(2)
    end)
    Util.AddClick(this.leftBtn,function()
        this:SwitchArrayShow(BtnType.Left)
    end)
    Util.AddClick(this.rightBtn,function()
        this:SwitchArrayShow(BtnType.Right)
    end)
    Util.AddClick(this.battleArrayDetails,function()
        this.battleArrayDetails:SetActive(false)
    end)
    Util.AddClick(this.nameBtn,function()
        this.SetBtnState(this.nameBtn)
        this.SetHeroPosNameOrLocation(1)
    end)
    Util.AddClick(this.locationBtn,function()
        this.SetBtnState(this.locationBtn)
        this.SetHeroPosNameOrLocation(2)
    end)

    Util.AddClick(this.detailsBtn, function()
        this.battleArrayDetails:SetActive(true)
    end)

    for index, value in ipairs(this.tabs) do
        Util.AddClick(value,function()
            curIndex = index
            this.SetArrInfo()
            this.SetTabState()
        end)
    end
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_panel)
    this.battlePanel = _panel
    this:RefreshTeskProgress()
    this:InitView()
end

function this:OnClose()
end

function this:OnDestroy()
end

---初始化面板
function this:InitView()
    curIndex = 1
    this.SetArrInfo()
    this.SetTabState()
    this.SetBtnState(this.nameBtn)
    this.SetHeroPosNameOrLocation(1)

    for index, value in ipairs(this.tabs) do
        local battleData = ConfigManager.GetConfigData(ConfigName.BattlePassShow, index)
        Util.GetGameObject(value,"Text"):GetComponent("Text").text = GetLanguageStrById(battleData.Tab)
        Util.GetGameObject(value,"Select"):GetComponent("Text").text = GetLanguageStrById(battleData.Tab)
    end
end

--设置按钮状态
function this.SetBtnState(_btn)
    for index, value in ipairs(this.btns) do
        local text = Util.GetGameObject(value,"Text"):GetComponent("Text")
        if value == _btn then
            value:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_duobianxing_11")
            value:GetComponent("Image").color = Color.New(255/255,209/255,42/255,255/255)
            text.color = Color.New(88/255,57/255,11/255,255/255)
        else
            value:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_shouzha_weixuanzhong")
            value:GetComponent("Image").color = Color.New(255/255,255/255,255/255,255/255)
            text.color = Color.New(255/255,255/255,255/255,128/255)
        end
    end
end

--设置tab状态
function this.SetTabState()
    for index, value in ipairs(this.tabs) do
        if index == curIndex then
            value:GetComponent("Image").sprite = Util.LoadSprite(tabBtnBg[index].select)
            this.SetActive(Util.GetGameObject(value,"Select"),true)
            this.SetActive(Util.GetGameObject(value,"Text"),false)
            this.title.sprite = Util.LoadSprite(tabBtnBg[index].title)
        else
            value:GetComponent("Image").sprite = Util.LoadSprite(tabBtnBg[index].default)
            this.SetActive(Util.GetGameObject(value,"Select"),false)
            this.SetActive(Util.GetGameObject(value,"Text"),true)
        end
    end
end

--设置英雄站位名字和定位的显隐：1名称 2定位
function this.SetHeroPosNameOrLocation(_index)
    --设置遮罩
    this.mask:SetActive(_index == 2)

    for index, value in ipairs(this.points) do
        local nameBg = Util.GetGameObject(value,"nameBg")
        local locations = Util.GetGameObject(value,"locations")
        this.SetActive(nameBg,_index == 1)
        this.SetActive(locations,_index == 2)
    end
end

--设置阵容信息
function this.SetArrInfo()
    local battleData = ConfigManager.GetConfigData(ConfigName.BattlePassShow, curIndex)
    this.detailsText.text = GetLanguageStrById(battleData.Desc)
    local heroData = {
        [1] = battleData.Hero1,
        [2] = battleData.Hero2,
        [3] = battleData.Hero3,
        [4] = battleData.Hero4,
        [5] = battleData.Hero5,
    }
    for i = 1, #heroData, 1 do
        local item = this.heros[i]
        local heroInfo = ConfigManager.GetConfigData(ConfigName.HeroConfig, tonumber(heroData[i][1]))
        item:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(nil,tonumber(heroData[i][2])))
        Util.GetGameObject(item, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroInfo.Icon))
        Util.GetGameObject(item, "name"):GetComponent("Text").text = GetLanguageStrById(heroInfo.ReadingName)
        Util.GetGameObject(item, "proBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(nil,tonumber(heroData[i][2])))
        Util.GetGameObject(item, "proBg/pro"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroInfo.PropertyName))
        local starGrid = Util.GetGameObject(item, "star")
        SetHeroStars(starGrid, tonumber(heroData[i][2]))

        Util.AddOnceClick(item,function ()
            UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroInfo.Id, tonumber(heroData[i][2]))
        end)
    end

    this.SetHeroPosInfo(heroData)
end

--设置英雄站位信息
function this.SetHeroPosInfo(_heroData)
    for index, value in ipairs(this.points) do
        this.SetActive(value, false)
        for i = 1, #_heroData do
            if index == tonumber(_heroData[i][7]) then
                value:GetComponent("Image").sprite = Util.LoadSprite(_heroData[i][8])
                this.SetActive(value, true)
                local heroInfo = ConfigManager.GetConfigData(ConfigName.HeroConfig, tonumber(_heroData[i][1]))
                Util.GetGameObject(value, "nameBg/location"):GetComponent("Image").sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(heroInfo.Profession))
                Util.GetGameObject(value, "nameBg/name"):GetComponent("Text").text = GetLanguageStrById(heroInfo.ReadingName)
                local desc = string.split(GetLanguageStrById(heroInfo.HeroLocationDesc1)," ")
                local locations = Util.GetGameObject(value, "locations")
                for i = 1, locations.transform.childCount do
                    local location = locations.transform:GetChild(i-1).gameObject
                    this.SetActive(location,false)
                    for _index, _value in ipairs(desc) do
                        if _index == i then
                            this.SetActive(location,true)
                            Util.GetGameObject(location,"Text"):GetComponent("Text").text = _value
                        end
                    end
                end
                Util.AddOnceClick(value,function ()
                    UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroInfo.Id, tonumber(_heroData[i][2]))
                end)
            end
        end
    end
end

--刷新任务进度
function this:RefreshTeskProgress()
    NetManager.BattlePassRequest(function(msg)
        this.taskText.text = msg.pross.."/"..battlePassConfig[1].TaskCount
    end)

    this.SetActive(this.getBtnRedPoint,TaskManager.BattlePasssTask())
end

-- --红点显隐
-- function this.RedPointBtn()
--     local isRedPoint = false
--     this.taskData = TaskManager.GetTypeTaskList(TaskTypeDef.BattlePass)
--     for index, value in ipairs(this.taskData) do
--         if value.state == 1 then
--             isRedPoint = true
--             return isRedPoint
--         end
--     end
--     return isRedPoint
-- end

---点击按钮切换阵容
function this:SwitchArrayShow(type)
    if type == BtnType.Left then
        curIndex = curIndex - 1
        if curIndex < 1 then curIndex = 4 end
    elseif type == BtnType.Right then
        curIndex = curIndex + 1
        if curIndex > 4 then curIndex = 1 end
    end
    this.SetArrInfo()
    this.SetTabState()
end

function this.SetActive(go, value)
    if value and not go.activeSelf then
        go:SetActive(value)
    elseif not value and go.activeSelf then
        go:SetActive(value)
    end
end

return this