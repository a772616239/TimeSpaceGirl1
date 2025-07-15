require("Base/BasePanel")
HandBookHeroAndEquipListPanel = Inherit(BasePanel)

local OpenType = 0   --1 英雄 2装备 3 法宝

--英雄列表
local tenGridList = {}
local sexGridList = {}
local fiveGridList = {}
local fourGridList = {}
local threeGridList = {}
local twoGridList = {}
local oneGridList = {}
--装备列表
local chuanShuoGridList = {}
local shiShiGridList = {}
local youXiuGridList = {}
local jingLiangGridList = {}
--法宝列表
local orangeGridList={}
local violetGridList={}
local blueGridList={}

local proId=0--0 全部  1 火 2风 3 水 4 地  5 光 6 暗
local tabs = {}
local orginLayer = 0
local orginLayer2 = 0
--初始化组件（用于子类重写）
function HandBookHeroAndEquipListPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.transform, "btnBack")

    --英雄
    self.heroScroll = Util.GetGameObject(self.transform, "heroScroll")
    self.heroScrollbar = Util.GetGameObject(self.transform, "heroScrollbar")
    self.card = poolManager:LoadAsset("card", PoolManager.AssetType.GameObject) 
    self.card.transform:SetParent(self.transform)  
    self.card:GetComponent("RectTransform").localScale = Vector3.New(1,1,1)
    Util.GetGameObject(self.card, "choosed").gameObject:SetActive(false)
    Util.GetGameObject(self.card, "sign").gameObject:SetActive(false)
    self.tenGrid = Util.GetGameObject(self.heroScroll.transform, "grid/tenGrid")
    self.sexGrid = Util.GetGameObject(self.heroScroll.transform, "grid/sexGrid")
    self.fiveGrid = Util.GetGameObject(self.heroScroll.transform, "grid/fiveGrid")
    self.fourGrid = Util.GetGameObject(self.heroScroll.transform, "grid/fourGrid")
    self.threeGrid = Util.GetGameObject(self.heroScroll.transform, "grid/threeGrid")
    self.twoGrid = Util.GetGameObject(self.heroScroll.transform, "grid/twoGrid")
    self.oneGrid = Util.GetGameObject(self.heroScroll.transform, "grid/oneGrid")

    self.tenStar = Util.GetGameObject(self.heroScroll.transform, "grid/tenStarNum")
    self.sexStar = Util.GetGameObject(self.heroScroll.transform, "grid/sexStarNum")
    self.fiveStar = Util.GetGameObject(self.heroScroll.transform, "grid/fiveStarNum")
    self.fourStar = Util.GetGameObject(self.heroScroll.transform, "grid/fourStarNum")
    self.threeStar = Util.GetGameObject(self.heroScroll.transform, "grid/threeStarNum")
    self.twoStar = Util.GetGameObject(self.heroScroll.transform, "grid/twoStarNum")
    self.oneStar = Util.GetGameObject(self.heroScroll.transform, "grid/oneStarNum")

    self.tenStarNum = Util.GetGameObject(self.heroScroll.transform, "grid/tenStarNum/star/Text/Text (1)"):GetComponent("Text")
    self.sexStarNum = Util.GetGameObject(self.heroScroll.transform, "grid/sexStarNum/star/Text/Text (1)"):GetComponent("Text")
    self.fiveStarNum = Util.GetGameObject(self.heroScroll.transform, "grid/fiveStarNum/star/Text/Text (1)"):GetComponent("Text")
    self.fourStarNum = Util.GetGameObject(self.heroScroll.transform, "grid/fourStarNum/star/Text/Text (1)"):GetComponent("Text")
    self.threeStarNum = Util.GetGameObject(self.heroScroll.transform, "grid/threeStarNum/star/Text/Text (1)"):GetComponent("Text")
    self.twoStarNum = Util.GetGameObject(self.heroScroll.transform, "grid/twoStarNum/star/Text/Text (1)"):GetComponent("Text")
    self.oneStarNum = Util.GetGameObject(self.heroScroll.transform, "grid/oneStarNum/star/Text/Text (1)"):GetComponent("Text")

    --装备
    self.equipScroll = Util.GetGameObject(self.transform, "equipScroll")
    self.equipScrollbar = Util.GetGameObject(self.transform, "equipScrollbar")
    self.equip = Util.GetGameObject(self.transform, "equip")
    self.chuanShuoGrid = Util.GetGameObject(self.equipScroll.transform, "grid/chuanShuoGrid")
    self.shiShiGrid = Util.GetGameObject(self.equipScroll.transform, "grid/shiShiGrid")
    self.youXiuGrid = Util.GetGameObject(self.equipScroll.transform, "grid/youXiuGrid")
    self.jingLiangGrid = Util.GetGameObject(self.equipScroll.transform, "grid/jingLiangGrid")
    self.chuanShuoNum = Util.GetGameObject(self.equipScroll.transform, "grid/chuanShuoNum/numInfo/numText/Text (1)"):GetComponent("Text")
    self.shiShiNum = Util.GetGameObject(self.equipScroll.transform, "grid/shiShiNum/numInfo/numText/Text (1)"):GetComponent("Text")
    self.youXiuNum = Util.GetGameObject(self.equipScroll.transform, "grid/youXiuNum/numInfo/numText/Text (1)"):GetComponent("Text")
    self.jingLiangNum = Util.GetGameObject(self.equipScroll.transform, "grid/jingLiangNum/numInfo/numText/Text (1)"):GetComponent("Text")
    --法宝
    self.talismanScroll=Util.GetGameObject(self.transform,"TalismanScroll")
    self.talismanScrollbar = Util.GetGameObject(self.transform, "TalismanScrollbar")
    self.talismanPre= Util.GetGameObject(self.transform, "TalismanPre")
    self.orangeGrid=Util.GetGameObject(self.talismanScroll.transform,"Grid/OrangeGrid")
    self.violetGrid=Util.GetGameObject(self.talismanScroll.transform,"Grid/VioletGrid")
    self.blueGrid=Util.GetGameObject(self.talismanScroll.transform,"Grid/BlueGrid")
    self.orangeNum=Util.GetGameObject(self.talismanScroll.transform, "Grid/OrangeNum/NumInfo/NumText/Text"):GetComponent("Text")
    self.violetNum=Util.GetGameObject(self.talismanScroll.transform,"Grid/VioletNum/NumInfo/NumText/Text"):GetComponent("Text")
    self.blueNum=Util.GetGameObject(self.talismanScroll.transform,"Grid/BlueNum/NumInfo/NumText/Text"):GetComponent("Text")

    self.BtView =SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)

    -- -- 缩放适配
    -- self.grid = Util.GetGameObject(self.heroScroll.transform, "grid")
    -- local gridx = self.grid.transform.rect.x
    -- local gridy = self.grid.transform.rect.y
    -- local rectx = -gridx*2
    -- self.adapterScale = 1
    -- if rectx < 1056 then
    --     self.adapterScale = rectx / 1056
    --     local function setAdapterData(go)
    --         go:GetComponent("GridLayoutGroup").cellSize = go:GetComponent("GridLayoutGroup").cellSize * self.adapterScale
    --         go.transform.sizeDelta = Vector2.New(rectx, 0)
    --     end

    --     setAdapterData(self.tenGrid)
    --     setAdapterData(self.sexGrid)
    --     setAdapterData(self.fiveGrid)
    --     setAdapterData(self.fourGrid)
    --     setAdapterData(self.threeGrid)
    --     setAdapterData(self.twoGrid)
    --     setAdapterData(self.oneGrid)
    -- end
    

    tenGridList = {}
    sexGridList = {}
    fiveGridList = {}
    fourGridList = {}
    threeGridList = {}
    twoGridList = {}
    oneGridList = {}

    chuanShuoGridList = {}
    shiShiGridList = {}
    youXiuGridList = {}
    jingLiangGridList = {}

    orangeGridList={}
    violetGridList={}
    blueGridList={}

    for i = 1, 1 do
        tenGridList[i] = Util.GetGameObject(self.heroScroll.transform, "grid/tenGrid/card ("..i..")")
        sexGridList[i] = Util.GetGameObject(self.heroScroll.transform, "grid/sexGrid/card ("..i..")")
        fiveGridList[i] = Util.GetGameObject(self.heroScroll.transform, "grid/fiveGrid/card ("..i..")")
        fourGridList[i] = Util.GetGameObject(self.heroScroll.transform, "grid/fourGrid/card ("..i..")")
        threeGridList[i] = Util.GetGameObject(self.heroScroll.transform, "grid/threeGrid/card ("..i..")")
        twoGridList[i] = Util.GetGameObject(self.heroScroll.transform, "grid/twoGrid/card ("..i..")")
        oneGridList[i] = Util.GetGameObject(self.heroScroll.transform, "grid/oneGrid/card ("..i..")")

        chuanShuoGridList[i] = Util.GetGameObject(self.equipScroll.transform, "grid/chuanShuoGrid/equip ("..i..")")
        shiShiGridList[i] = Util.GetGameObject(self.equipScroll.transform, "grid/shiShiGrid/equip ("..i..")")
        youXiuGridList[i] = Util.GetGameObject(self.equipScroll.transform, "grid/youXiuGrid/equip ("..i..")")
        jingLiangGridList[i] = Util.GetGameObject(self.equipScroll.transform, "grid/jingLiangGrid/equip ("..i..")")

        orangeGridList[i]=Util.GetGameObject(self.orangeGrid.transform,"equip ("..i..")")
        violetGridList[i]=Util.GetGameObject(self.violetGrid.transform,"equip ("..i..")")
        blueGridList[i]=Util.GetGameObject(self.blueGrid.transform,"equip ("..i..")")
    end
    --self.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    --self.BtView2 = SubUIManager.Open(SubUIConfig.BtView2, self.gameObject.transform)
    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    self.selectBtn = Util.GetGameObject(self.gameObject, "Tabs/selectBtn")
    for i = 0, 6 do
        tabs[i] = Util.GetGameObject(self.transform, "Tabs/grid/Btn" .. i)
    end
    self.Tabs = Util.GetGameObject(self.gameObject, "Tabs")
end

--绑定事件（用于子类重写）·
function HandBookHeroAndEquipListPanel:BindEvent()

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
    for i = 0, 6 do
        Util.AddClick(tabs[i], function()
            if i == proId then
                proId=ProIdConst.All
            else
                proId=i
            end
            self:OnShowHeroFun()
        end)
    end
end
--添加事件监听（用于子类重写）
function HandBookHeroAndEquipListPanel:AddListener()

end
--移除事件监听（用于子类重写）
function HandBookHeroAndEquipListPanel:RemoveListener()

end
--界面打开时调用（用于子类重写）
function HandBookHeroAndEquipListPanel:OnOpen(_type)

    -- proId=ProIdConst.All
    OpenType = _type
    --self.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.RolePanel })
    --self.BtView2:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView2.HandBookPanel })
    self.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    self.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.HandBook})
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HandBookHeroAndEquipListPanel:OnShow()

    proId = 0
    if OpenType == 1 then
        self.heroScroll:SetActive(true)
        self.heroScrollbar:SetActive(true)
        self.equipScroll:SetActive(false)
        self.equipScrollbar:SetActive(false)
        self.talismanScroll:SetActive(false)
        self.talismanScrollbar:SetActive(false)
        self.Tabs:SetActive(true)
        -- proId=ProIdConst.All
        self:OnShowHeroFun()
    elseif OpenType == 2 then
        self.heroScroll:SetActive(false)
        self.heroScrollbar:SetActive(false)
        self.equipScroll:SetActive(true)
        self.equipScrollbar:SetActive(true)
        self.talismanScroll:SetActive(false)
        self.talismanScrollbar:SetActive(false)
        self.Tabs:SetActive(false)
        self:OnShowEquipFun()
    elseif OpenType==3 then
        self.heroScroll:SetActive(false)
        self.heroScrollbar:SetActive(false)
        self.equipScroll:SetActive(false)
        self.equipScrollbar:SetActive(false)
        self.talismanScroll:SetActive(true)
        self.talismanScrollbar:SetActive(true)
        self.Tabs:SetActive(false)
        self:OnShowTalismanFun()
    end
end
--界面关闭时调用（用于子类重写）
function HandBookHeroAndEquipListPanel:OnClose()

end
--界面销毁时调用（用于子类重写）
function HandBookHeroAndEquipListPanel:OnDestroy()

    SubUIManager.Close(self.UpView)
    SubUIManager.Close(self.BtView)
    --SubUIManager.Close(self.BtView)
    --SubUIManager.Close(self.BtView2)
end
function HandBookHeroAndEquipListPanel:OnSortingOrderChange()
    for _,go in pairs(tenGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end
    for _,go in pairs(sexGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end
    for _,go in pairs(fiveGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end
    for _,go in pairs(fourGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end
    for _,go in pairs(threeGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end
    for _,go in pairs(twoGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end
    for _,go in pairs(oneGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder  

    self.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
end

--英雄展示
function HandBookHeroAndEquipListPanel:OnShowHeroFun()
    self:SetSelectBtn()
    --得到所有的对应星级的英雄
    local tenHeroList = {}
    local sexHeroList = {}
    local fiveHeroList = {}
    local fourHeroList = {}
    local threeHeroList = {}
    local twoHeroList = {}
    local oneHeroList = {}
    for id, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroConfig)) do      
        --5星最高星级是10的要在十星里面显示出来
        if v.Star == 5 and v.MaxRank >= 10 and (proId == 0 or v.PropertyName == proId) then
            table.insert(tenHeroList,v)
        end
        --所有的5星都要在六星里面显示出来
        if v.Star == 5 and (proId == 0 or v.PropertyName == proId) then
            table.insert(fiveHeroList,v)
            table.insert(sexHeroList,v)
        elseif v.Star >= 4 and (proId == 0 or v.PropertyName == proId)  then
            table.insert(fourHeroList,v)
        elseif v.Star >= 3 and (proId == 0 or v.PropertyName == proId)  then
            table.insert(threeHeroList,v)
        elseif v.Star >= 2 and (proId == 0 or v.PropertyName == proId)  then
            table.insert(twoHeroList,v)
        elseif v.Star >= 1 and (proId == 0 or v.PropertyName == proId)  then
            table.insert(oneHeroList,v)
        end
    end
    self:SortHeroNatural(tenHeroList)
    self:SortHeroNatural(sexHeroList)
    self:SortHeroNatural(fiveHeroList)
    self:SortHeroNatural(fourHeroList)
    self:SortHeroNatural(threeHeroList)
    self:SortHeroNatural(twoHeroList)
    self:SortHeroNatural(oneHeroList)

    local herodatas={}
    herodatas[10]=tenHeroList
    herodatas[6]=sexHeroList
    herodatas[5]=fiveHeroList
    herodatas[4]=fourHeroList
    herodatas[3]=threeHeroList
    herodatas[2]=twoHeroList
    herodatas[1]=oneHeroList
    PlayerManager.heroHandBookListData=herodatas

    --计算玩家拥有的英雄中对应星级的英雄的数量
    local curtenStarActiveNum = 0
    local cursexStarActiveNum = 0
    local curfiveStarActiveNum = 0
    local curfourStarActiveNum = 0
    local curthreeStarActiveNum = 0
    local curtwoStarActiveNum = 0
    local curoneStarActiveNum = 0
    for i, v in pairs(PlayerManager.heroHandBook) do
        local conFig = ConfigManager.GetConfigData(ConfigName.HeroConfig,i)
        if conFig then      
            if PlayerManager.GetHeroDataByStar(10,conFig.Id) and (proId == 0 or conFig.PropertyName == proId) then
                curtenStarActiveNum = curtenStarActiveNum + 1
            end      
            if PlayerManager.GetHeroDataByStar(6,conFig.Id) and (proId == 0 or conFig.PropertyName == proId) then               
                cursexStarActiveNum = cursexStarActiveNum + 1
            end        
            if conFig.Star == 5  and (proId == 0 or conFig.PropertyName == proId) then
                curfiveStarActiveNum = curfiveStarActiveNum + 1
            elseif  conFig.Star == 4  and (proId == 0 or conFig.PropertyName == proId) then
                curfourStarActiveNum = curfourStarActiveNum + 1
            elseif  conFig.Star == 3  and (proId == 0 or conFig.PropertyName == proId) then
                curthreeStarActiveNum = curthreeStarActiveNum + 1
            elseif  conFig.Star == 2  and (proId == 0 or conFig.PropertyName == proId) then
                curtwoStarActiveNum = curtwoStarActiveNum + 1
            elseif  conFig.Star == 1  and (proId == 0 or conFig.PropertyName == proId) then
                curoneStarActiveNum = curoneStarActiveNum + 1
            end
        end
    end  
    

    self.tenStarNum.text = GetLanguageStrById(11096)..curtenStarActiveNum.."/"..#tenHeroList
    self.tenStar.gameObject:SetActive(#tenHeroList>0)
    self.tenGrid.gameObject:SetActive(#tenHeroList>0)
    self.sexStarNum.text = GetLanguageStrById(11096)..cursexStarActiveNum.."/"..#sexHeroList
    self.sexStar.gameObject:SetActive(#sexHeroList>0)
    self.sexGrid.gameObject:SetActive(#tenHeroList>0)
    self.fiveStarNum.text = GetLanguageStrById(11096)..curfiveStarActiveNum.."/"..#fiveHeroList
    self.fiveStar.gameObject:SetActive(#fiveHeroList>0)
    self.fiveGrid.gameObject:SetActive(#fiveHeroList>0)
    self.fourStarNum.text = GetLanguageStrById(11096)..curfourStarActiveNum.."/"..#fourHeroList
    self.fourStar.gameObject:SetActive(#fourHeroList>0)
    self.fourGrid.gameObject:SetActive(#fourHeroList>0)
    self.threeStarNum.text = GetLanguageStrById(11096)..curthreeStarActiveNum.."/"..#threeHeroList
    self.threeStar.gameObject:SetActive(#threeHeroList>0)
    self.threeGrid.gameObject:SetActive(#threeHeroList>0)
    self.twoStarNum.text = GetLanguageStrById(11096)..curtwoStarActiveNum.."/"..#twoHeroList
    self.twoStar.gameObject:SetActive(#twoHeroList>0)
    self.twoGrid.gameObject:SetActive(#twoHeroList>0)
    self.oneStarNum.text = GetLanguageStrById(11096)..curoneStarActiveNum.."/"..#oneHeroList
    self.oneStar.gameObject:SetActive(#oneHeroList>0)
    self.oneGrid.gameObject:SetActive(#oneHeroList>0)

    --十星的
    for i = 1, math.max(#tenHeroList, #tenGridList) do
        local go = tenGridList[i]
        if not go or (go and not go.gameObject) then
            go = self:GeneralNewGoPre(1,i,self.tenGrid)
            tenGridList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #tenHeroList do
        tenGridList[i]:SetActive(true)
        self:OnShowSingleHeroData(tenGridList[i],tenHeroList[i],10,255)
    end
    self.tenGrid.gameObject:SetActive(#tenHeroList>0)
    --六星的
    for i = 1, math.max(#sexHeroList, #sexGridList) do
        local go = sexGridList[i]
        if not go or (go and not go.gameObject) then
            go = self:GeneralNewGoPre(1,i,self.sexGrid)
            sexGridList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #sexHeroList do
        sexGridList[i]:SetActive(true)
        self:OnShowSingleHeroData(sexGridList[i],sexHeroList[i],6,145)
    end
    self.sexGrid.gameObject:SetActive(#sexGridList>0)
    --五星的
    for i = 1, math.max(#fiveHeroList, #fiveGridList) do
        local go = fiveGridList[i]
        if not go or (go and not go.gameObject) then
            go = self:GeneralNewGoPre(1,i,self.fiveGrid)
            fiveGridList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #fiveHeroList do
        fiveGridList[i]:SetActive(true)
        self:OnShowSingleHeroData(fiveGridList[i],fiveHeroList[i])
    end
    self.fiveGrid.gameObject:SetActive(#fiveGridList>0)
    --四星的
    for i = 1, math.max(#fourHeroList, #fourGridList) do
        local go = fourGridList[i]
        if not go or (go and not go.gameObject) then
            go = self:GeneralNewGoPre(1,i,self.fourGrid)
            fourGridList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #fourHeroList do
        fourGridList[i]:SetActive(true)
        self:OnShowSingleHeroData(fourGridList[i],fourHeroList[i])
    end
    self.fourGrid.gameObject:SetActive(#fourGridList>0)
    --三星的
    for i = 1, math.max(#threeHeroList, #threeGridList) do
        local go = threeGridList[i]
        if not go or (go and not go.gameObject) then
            go = self:GeneralNewGoPre(1,i,self.threeGrid)
            threeGridList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #threeHeroList do
        threeGridList[i]:SetActive(true)
        self:OnShowSingleHeroData(threeGridList[i],threeHeroList[i])
    end
    self.threeGrid.gameObject:SetActive(#threeGridList>0)
    --二星的
    for i = 1, math.max(#twoHeroList, #twoGridList) do
        local go = twoGridList[i]
        if not go or (go and not go.gameObject) then
            go = self:GeneralNewGoPre(1,i,self.twoGrid)
            twoGridList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #twoHeroList do
        twoGridList[i]:SetActive(true)
        self:OnShowSingleHeroData(twoGridList[i],twoHeroList[i])
    end
    self.twoGrid.gameObject:SetActive(#oneHeroList>0)
    --一星的
    for i = 1, math.max(#oneHeroList, #twoGridList) do
        local go = oneGridList[i]
        if not go or (go and not go.gameObject) then
            go = self:GeneralNewGoPre(1,i,self.oneGrid)
            oneGridList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #oneHeroList do
        oneGridList[i]:SetActive(true)
        self:OnShowSingleHeroData(oneGridList[i],oneHeroList[i])
    end
    self.oneGrid.gameObject:SetActive(#oneHeroList>0)

    for _,go in pairs(tenGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer2)
    end
    for _,go in pairs(sexGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer2)
    end
    for _,go in pairs(fiveGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer2)
    end
    for _,go in pairs(fourGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer2)
    end
    for _,go in pairs(threeGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer2)
    end
    for _,go in pairs(twoGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer2)
    end
    for _,go in pairs(oneGridList) do 
        Util.AddParticleSortLayer(go, self.sortingOrder - orginLayer2)
    end
    orginLayer2 =self.sortingOrder
    orginLayer = self.sortingOrder
end

--装备展示
function HandBookHeroAndEquipListPanel:OnShowEquipFun()
    local chuanShuoEquipList = {}
    local shiShiEquipList = {}
    local youXiuEquipList = {}
    local jingLiangEquipList = {}
    for id, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.EquipConfig)) do
        if v.IfShow == 1 then
            if v.Quality == 5 then
                table.insert(chuanShuoEquipList,v)
            elseif v.Quality == 4 then
                table.insert(shiShiEquipList,v)
            elseif v.Quality == 3 then
                table.insert(youXiuEquipList,v)
            elseif v.Quality == 2 then
                table.insert(jingLiangEquipList,v)
            end
        end
    end

    local curchaunShuoActiveNum = 0
    local curshiShiActiveNum = 0
    local curyouXiuActiveNum = 0
    local curjingLiangActiveNum = 0
    for i, v in pairs(PlayerManager.equipHandBook) do
        local conFig = ConfigManager.GetConfigData(ConfigName.EquipConfig,v)
        if conFig and conFig.IfShow == 1 then
            if conFig.Quality == 5 then
                curchaunShuoActiveNum = curchaunShuoActiveNum + 1
            elseif  conFig.Quality == 4 then
                curshiShiActiveNum = curshiShiActiveNum + 1
            elseif  conFig.Quality == 3 then
                curyouXiuActiveNum = curyouXiuActiveNum + 1
            elseif  conFig.Quality == 2 then
                curjingLiangActiveNum = curjingLiangActiveNum + 1
            end
        end
    end
    --传说装备
    if chuanShuoEquipList and #chuanShuoEquipList > 0 then
        self.chuanShuoNum.text = GetLanguageStrById(11096)..curchaunShuoActiveNum.."/"..#chuanShuoEquipList
        for i = 1, math.max(#chuanShuoEquipList, #chuanShuoGridList) do
            local go = chuanShuoGridList[i]
            if not go or (go and not go.gameObject) then
                go = self:GeneralNewGoPre(2,i,self.chuanShuoGrid)
                chuanShuoGridList[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #chuanShuoEquipList do
            chuanShuoGridList[i]:SetActive(true)
            self:OnShowSingleEquipData(chuanShuoGridList[i],chuanShuoEquipList[i])
        end
        Util.GetGameObject(self.equipScroll.transform, "chuanShuoNum"):SetActive(true)
        self.chuanShuoGrid:SetActive(true)
    else
        Util.GetGameObject(self.equipScroll.transform, "chuanShuoNum"):SetActive(false)
        self.chuanShuoGrid:SetActive(false)
    end
    --史诗装备
    if shiShiEquipList and #shiShiEquipList > 0 then
        self.shiShiNum.text = GetLanguageStrById(11096)..curshiShiActiveNum.."/"..#shiShiEquipList
        for i = 1, math.max(#shiShiEquipList, #shiShiGridList) do
            local go = shiShiGridList[i]
            if not go or (go and not go.gameObject) then
                go = self:GeneralNewGoPre(2,i,self.shiShiGrid)
                shiShiGridList[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #shiShiEquipList do
            shiShiGridList[i]:SetActive(true)
            self:OnShowSingleEquipData(shiShiGridList[i],shiShiEquipList[i])
        end
        Util.GetGameObject(self.equipScroll.transform, "shiShiNum"):SetActive(true)
        self.shiShiGrid:SetActive(true)
    else
        Util.GetGameObject(self.equipScroll.transform, "shiShiNum"):SetActive(false)
        self.shiShiGrid:SetActive(false)
    end
    --优秀装备
    if youXiuEquipList and #youXiuEquipList > 0 then
        self.youXiuNum.text = GetLanguageStrById(11096)..curyouXiuActiveNum.."/"..#youXiuEquipList
        for i = 1, math.max(#youXiuEquipList, #youXiuGridList) do
            local go = youXiuGridList[i]
            if not go or (go and not go.gameObject) then
                go = self:GeneralNewGoPre(2,i,self.youXiuGrid)
                youXiuGridList[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #youXiuEquipList do
            youXiuGridList[i]:SetActive(true)
            self:OnShowSingleEquipData(youXiuGridList[i],youXiuEquipList[i])
        end
        Util.GetGameObject(self.equipScroll.transform, "youXiuNum"):SetActive(true)
        self.youXiuGrid:SetActive(true)
    else
        Util.GetGameObject(self.equipScroll.transform, "youXiuNum"):SetActive(false)
        self.youXiuGrid:SetActive(false)
    end
    --精良装备
    if jingLiangEquipList and #jingLiangEquipList > 0 then
        self.jingLiangNum.text = GetLanguageStrById(11096)..curjingLiangActiveNum.."/"..#jingLiangEquipList
        for i = 1, math.max(#jingLiangEquipList, #jingLiangGridList) do
            local go = jingLiangGridList[i]
            if not go or (go and not go.gameObject) then
                go = self:GeneralNewGoPre(2,i,self.jingLiangGrid)
                jingLiangGridList[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #jingLiangEquipList do
            jingLiangGridList[i]:SetActive(true)
            self:OnShowSingleEquipData(jingLiangGridList[i],jingLiangEquipList[i])
        end
        Util.GetGameObject(self.equipScroll.transform, "jingLiangNum"):SetActive(true)
        self.jingLiangGrid:SetActive(true)
    else
        Util.GetGameObject(self.equipScroll.transform, "jingLiangNum"):SetActive(false)
        self.jingLiangGrid:SetActive(false)
    end
end
--法宝展示(脚本名该换了)
function HandBookHeroAndEquipListPanel:OnShowTalismanFun()
    self:SetSelectBtn()
    local orangeTalismanList={}
    local violetTalismanList={}
    local blueTalismanList={}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ItemConfig)) do
        if v.ItemType==14 then
            if v.Quantity==5 then
                table.insert(orangeTalismanList,v)
            elseif v.Quantity==4 then
                table.insert(violetTalismanList,v)
            elseif v.Quantity==3 then
                table.insert(blueTalismanList,v)
            end
        end
    end

    --搜集进度
    local curOrangeActiveNum=0
    local curVioletActiveNum=0
    local curBlueActiveNum=0
    for i, v in pairs(PlayerManager.talismanHandBook) do
        local conFig={}
        conFig = ConfigManager.GetConfigData(ConfigName.ItemConfig,v)
        if conFig then
            if conFig.Quantity == 5 then
                curOrangeActiveNum = curOrangeActiveNum + 1
            elseif  conFig.Quantity == 4 then
                curVioletActiveNum = curVioletActiveNum + 1
            elseif  conFig.Quantity == 3 then
                curBlueActiveNum = curBlueActiveNum + 1
            end
        end
    end
    --橙色法宝
    if orangeTalismanList and #orangeTalismanList>0 then
        self.orangeNum.text=GetLanguageStrById(11096)..curOrangeActiveNum.."/"..#orangeTalismanList
        for i = 1, math.max(#orangeTalismanList,#orangeGridList) do
            local go=orangeGridList[i]
            if not go or (go and not go.gameObject) then
                go=self:GeneralNewGoPre(3,i,self.orangeGrid)
                orangeGridList[i]=go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #orangeTalismanList do
            orangeGridList[i]:SetActive(true)
            self:OnShowSingleTalismanData(orangeGridList[i],orangeTalismanList[i])
        end
        Util.GetGameObject(self.talismanScroll.transform,"Grid/OrangeNum"):SetActive(true)
        self.orangeGrid:SetActive(true)
    else
        Util.GetGameObject(self.talismanScroll.transform,"Grid/OrangeNum"):SetActive(false)
        self.orangeGrid:SetActive(false)
    end
    --紫色法宝
    if violetTalismanList and #violetTalismanList>0 then
        self.violetNum.text=GetLanguageStrById(11096)..curVioletActiveNum.."/"..#violetTalismanList
        for i = 1, math.max(#violetTalismanList,#violetGridList) do
            local go=violetGridList[i]
            if not go or (go and not go.gameObject) then
                go=self:GeneralNewGoPre(3,i,self.violetGrid)
                violetGridList[i]=go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #violetTalismanList do
            violetGridList[i]:SetActive(true)
            self:OnShowSingleTalismanData(violetGridList[i],violetTalismanList[i])
        end
        Util.GetGameObject(self.talismanScroll.transform,"Grid/VioletNum"):SetActive(true)
        self.violetGrid:SetActive(true)
    else
        Util.GetGameObject(self.talismanScroll.transform,"Grid/VioletNum"):SetActive(false)
        self.violetGrid:SetActive(false)
    end
    --蓝色法宝
    if blueTalismanList and #blueTalismanList>0 then
        self.blueNum.text=GetLanguageStrById(11096)..curBlueActiveNum.."/"..#blueTalismanList
        for i = 1, math.max(#blueTalismanList,#blueGridList) do
            local go=blueGridList[i]
            if not go or (go and not go.gameObject) then
                go=self:GeneralNewGoPre(3,i,self.blueGrid)
                blueGridList[i]=go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #blueTalismanList do
            blueGridList[i]:SetActive(true)
            self:OnShowSingleTalismanData(blueGridList[i],blueTalismanList[i])
        end
        Util.GetGameObject(self.talismanScroll.transform,"Grid/BlueNum"):SetActive(true)
        self.blueGrid:SetActive(true)
    else
        Util.GetGameObject(self.talismanScroll.transform,"Grid/BlueNum"):SetActive(false)
        self.blueGrid:SetActive(false)
    end
end

--生成不同类型图鉴预制的通用方法
function HandBookHeroAndEquipListPanel:GeneralNewGoPre(_type,_index,_grid)
    local go
    if _type == 1 then
        go=newObject(self.card)
        go.transform:SetParent(_grid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition=Vector3.zero;
        go.gameObject.name = "card (".._index..")"
    elseif _type == 2 then
        go=newObject(self.equip)
        go.transform:SetParent(_grid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition=Vector3.zero;
        go.gameObject.name = "equip (".._index..")"
    elseif _type==3 then
        go=newObject(self.talismanPre)
        go.transform:SetParent(_grid.transform)
        go.transform.localScale=Vector3.one
        go.transform.localPosition=Vector3.zero
        go.gameObject.name="Talisman (".._index..")"
    end
    return go
end
--设置猎妖师数据
function HandBookHeroAndEquipListPanel:OnShowSingleHeroData(...)
    local param = {...}
    local heroData = param[2]
    local _go = param[1]
    local star = heroData.Star
    if param[3] then
        star = param[3]
    end
    local lv = 1
    if param[4] and param[4] > 0 then
        lv = param[4]
    end
    SetHeroBg(Util.GetGameObject(_go.transform, "card"), Util.GetGameObject(_go.transform, "card/bg"),star,heroData.Quality)
    
    if lv and lv > 0 then
        Util.GetGameObject(_go.transform, "card/lv/Text"):GetComponent("Text").text = lv
    else
        Util.GetGameObject(_go.transform, "card/lv/Text"):GetComponent("Text").text = 1
    end

    Util.GetGameObject(_go.transform, "card/name"):GetComponent("Text").text = GetLanguageStrById(heroData.ReadingName)
    Util.GetGameObject(_go.transform, "card/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.Painting))
    -- Util.GetGameObject(_go.transform, "card/pos/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(heroData.Profession))
    Util.GetGameObject(_go.transform, "card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.PropertyName))
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, star)
    Util.AddOnceClick(Util.GetGameObject(_go.transform, "card"), function()
        UIManager.OpenPanel(UIName.HandBookHeroInfoPanel,heroData,proId,star)
    end)

    if PlayerManager.GetHeroDataByStar(star,heroData.Id) then
        Util.SetGray(Util.GetGameObject(_go.transform, "card/icon"), false)
        Util.SetGray(Util.GetGameObject(_go.transform, "card/pro/Image"), false)
        Util.GetGameObject(_go.transform, "card"):GetComponent("Image").material = nil
    else
        Util.SetGray(Util.GetGameObject(_go.transform, "card/icon"), true)
        Util.SetGray(Util.GetGameObject(_go.transform, "card/pro/Image"), true)
        Util.GetGameObject(_go.transform, "card"):GetComponent("Image").material = Util.GetGameObject(_go.transform, "card/icon"):GetComponent("Image").material
    end
end
--设置装备数据
function HandBookHeroAndEquipListPanel:OnShowSingleEquipData(_go,_equipData)
    local equipData = _equipData
    local itemConFigData = ConfigManager.GetConfigData(ConfigName.ItemConfig,equipData.Id)
    Util.GetGameObject(_go.transform, "GameObject/item/resetLv"):SetActive(false)
    Util.GetGameObject(_go.transform, "GameObject/item/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(equipData.Quality))
    if itemConFigData then
        Util.GetGameObject(_go.transform, "GameObject/item/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConFigData.ResourceID))
    end
    Util.GetGameObject(_go.transform, "GameObject/name"):GetComponent("Text").text = GetLanguageStrById(equipData.Name)
    Util.AddOnceClick(Util.GetGameObject(_go.transform, "GameObject/item/frame"), function()
        UIManager.OpenPanel(UIName.HandBookEquipInfoPanel,equipData.Id)
    end)
    if PlayerManager.equipHandBook[equipData.Id] == nil then
        Util.SetGray(_go, true)
    else
        Util.SetGray(_go, false)
    end
end
--设置法宝数据
function HandBookHeroAndEquipListPanel:OnShowSingleTalismanData(_go,_talismanData)
    local talismanData = _talismanData
    local itemConFigData= ConfigManager.GetConfigData(ConfigName.ItemConfig,talismanData.Id)
    --设置星级
    local starGrid=Util.GetGameObject(_go.transform,"GameObject/item/star")
    SetHeroStars(starGrid,talismanData.Quantity)
    Util.GetGameObject(_go.transform,"GameObject/item/resetLv"):SetActive(false)
    Util.GetGameObject(_go.transform, "GameObject/item/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(talismanData.Quantity))
    if itemConFigData then
        Util.GetGameObject(_go.transform, "GameObject/item/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConFigData.ResourceID))
    end
    Util.GetGameObject(_go.transform, "GameObject/name"):GetComponent("Text").text = talismanData.Name
    Util.AddOnceClick(Util.GetGameObject(_go.transform, "GameObject/item/frame"), function()
        UIManager.OpenPanel(UIName.HandBookTalismanInfoPanel,talismanData.Id)
        
    end)
    if PlayerManager.talismanHandBook[talismanData.Id] == nil then
        Util.SetGray(_go, true)
    else
        Util.SetGray(_go, false)
    end
end

--设置选中按钮
function HandBookHeroAndEquipListPanel:SetSelectBtn()
    -- self.selectBtn:SetActive(proId ~= ProIdConst.All)
    if proId ~= ProIdConst.All then
        self.selectBtn.transform.localPosition = tabs[proId].transform.localPosition
    else
        self.selectBtn.transform.localPosition = Vector3.New(-336, 0, 0)
    end
end
function HandBookHeroAndEquipListPanel:SortHeroNatural(heroList)
    table.sort(heroList, function(a, b)
        if a.Natural == b.Natural then
            return a.Id < b.Id
        else
            return a.Natural > b.Natural
        end
    end)
end
return HandBookHeroAndEquipListPanel