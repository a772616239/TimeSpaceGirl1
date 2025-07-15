require("Base/BasePanel")
DiffmonsterEditPopup = Inherit(BasePanel)
local this=DiffmonsterEditPopup
-- local diffmonsterOrder = {1,9,3,5,4,6,8,7,10,2}
local diffmonsterGOList = {}
local diffmonsterUnGOList = {}
local selectPokemonIdList={} --选中异妖列表
local openPanelSelectDataList={}
local openPanel
local curFormationIndex

-- 异妖表id对应资源
local _IconConfig = {
    [1] = "bd_banner-001",
    [2] = "bd_banner-010",
    [3] = "bd_banner-003",
    [4] = "bd_banner-005",
    [5] = "bd_banner-004",
    [6] = "bd_banner-006",
    [7] = "bd_banner-008",
    [8] = "bd_banner-007",
    [9] = "bd_banner-002",
    [10] = "bd_banner-009",
}

---------------------------------
local curIndex=0 --当前选中期类型
local isSelect=false --默认未选择
---------------------------------
--初始化组件（用于子类重写）
function DiffmonsterEditPopup:InitComponent()

    self.BtnBack = Util.GetGameObject(self.transform, "bg/btnBack")

    this.itemRoot = Util.GetGameObject(self.gameObject, "bg/scroll/grid")
    this.item = Util.GetGameObject(self.gameObject, "bg/scroll/grid/item")
    -- 倒序创建物体，最强的再上面
    for i = #_IconConfig, 1, -1 do
        if not diffmonsterGOList[i] then
            diffmonsterGOList[i] = newObjToParent(this.item, this.itemRoot)
            diffmonsterGOList[i]:SetActive(true)
            diffmonsterGOList[i]:GetComponent("Image").sprite = Util.LoadSprite(_IconConfig[i])
        end
    end
    
    this.selectOne = Util.GetGameObject(self.transform, "selectOne")
    this.selectTwo = Util.GetGameObject(self.transform, "selectTwo")
    this.selectThree = Util.GetGameObject(self.transform, "selectThree")
    diffmonsterUnGOList[1]= this.selectOne
    diffmonsterUnGOList[2]= this.selectTwo
    diffmonsterUnGOList[3]= this.selectThree
    this.btnSure = Util.GetGameObject(self.transform, "bg/btnSure")

    this.diffItemRoo = Util.GetGameObject(self.gameObject, "bg/scroll/grid")
    

end

--绑定事件（用于子类重写）
function DiffmonsterEditPopup:BindEvent()

    for i=1, #_IconConfig do
        Util.AddOnceClick(diffmonsterGOList[i], function()
            
            this.SelectUpdata(i)
        end)
    end
    Util.AddClick(self.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnSure, function()
        local selectPokemonIdListData={}
        local pokemonList={}
        for i = 1, #selectPokemonIdList do
            local singleData={}
            singleData.pokemonId=selectPokemonIdList[i][1]
            singleData.position=selectPokemonIdList[i][2]
            table.insert(pokemonList,{selectPokemonIdList[i][1],selectPokemonIdList[i][2]})
            table.insert(selectPokemonIdListData,singleData)
        end
        
        FormationManager.RefreshFormation(curFormationIndex,FormationManager.formationList[curFormationIndex].teamHeroInfos,"",selectPokemonIdListData,true)
        openPanel.UpdataYiYaoData(pokemonList)
        self:ClosePanel()
    end)
    Util.AddClick(this.selectOne, function()
        --if curIndex ~= 1 then
        --    PopupTipPanel.ShowTip("前期已选择！")
        --else
            this.SelectUnUpdata(1)
        --end
    end)
    Util.AddClick(this.selectTwo, function()
        --if curIndex~=2 then
        --    PopupTipPanel.ShowTip("中期已选择！")
        --else
            this.SelectUnUpdata(2)
        --end
    end)
    Util.AddClick(this.selectThree, function()
        --if curIndex~=3 then
        --    PopupTipPanel.ShowTip("后期已选择！")
        --else
            this.SelectUnUpdata(3)
        --end
    end)
end

--添加事件监听（用于子类重写）
function DiffmonsterEditPopup:AddListener()

end

--移除事件监听（用于子类重写）
function DiffmonsterEditPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function DiffmonsterEditPopup:OnOpen(...)

    local data={...}

    openPanel=data[1]
    curFormationIndex=data[2]
    curIndex=data[3]
    local pokemonList = {}
    local curFormation = FormationManager.GetFormationByID(curFormationIndex)
    for i = 1, #curFormation.teamPokemonInfos do
        table.insert(pokemonList,{curFormation.teamPokemonInfos[i].pokemonId,curFormation.teamPokemonInfos[i].position})
    end

    openPanelSelectDataList=pokemonList

    selectPokemonIdList={}--=curSelectIds
    local allPokemonData=DiffMonsterManager.pokemonList
    for i = 1, #allPokemonData do
        if allPokemonData[i].stage>0 then
            diffmonsterGOList[i]:SetActive(true)
        else
            diffmonsterGOList[i]:SetActive(false)
        end
    end
    for i = 1, #openPanelSelectDataList do
        local curdiffmonsterUnGOList =  diffmonsterUnGOList[openPanelSelectDataList[i][2]]
        if #openPanelSelectDataList>=i then
            
            curdiffmonsterUnGOList.transform:SetParent(diffmonsterGOList[openPanelSelectDataList[i][1]].transform)
            curdiffmonsterUnGOList.transform.localScale = Vector3.one
            curdiffmonsterUnGOList.transform.localPosition=Vector3.zero;
            curdiffmonsterUnGOList:SetActive(true)
        else
            curdiffmonsterUnGOList:SetActive(false)
        end
    end
    selectPokemonIdList=openPanelSelectDataList
end

--界面关闭时调用（用于子类重写）
function DiffmonsterEditPopup:OnClose()

    isSelect=false
    this.selectOne.transform:SetParent(this.transform)
    this.selectTwo.transform:SetParent(this.transform)
    this.selectThree.transform:SetParent(this.transform)
    this.selectOne:SetActive(false)
    this.selectTwo:SetActive(false)
    this.selectThree:SetActive(false)
    selectPokemonIdList = {}
end

--界面销毁时调用（用于子类重写）
function DiffmonsterEditPopup:OnDestroy()

    diffmonsterGOList = {}
end 


-------------------------------------------------
--点击选中
function this.SelectUpdata(index)
    isSelect=true
    --选中时先删除表数据
    if #selectPokemonIdList>0 then
        for i, v in ipairs(selectPokemonIdList) do
            if curIndex==v[2] then
                table.remove(selectPokemonIdList,i)
                
            end
        end
    end

    local maxNum = ActTimeCtrlManager.MaxDemonNum()
    if #selectPokemonIdList>=maxNum then
        if maxNum < 3 then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.TipText(maxNum + 1))
        end
        return
    else
        if selectPokemonIdList[#selectPokemonIdList+1]==nil then
            selectPokemonIdList[#selectPokemonIdList+1]={index,curIndex}
        else
            return
        end
    end

    if curIndex==1 then
        this.selectOne.transform:SetParent(diffmonsterGOList[index].transform)
        this.selectOne.transform.localScale = Vector3.one
        this.selectOne.transform.localPosition=Vector3.zero;
        this.selectOne:SetActive(true)
    elseif curIndex==2 then
        this.selectTwo .transform:SetParent(diffmonsterGOList[index].transform)
        this.selectTwo.transform.localScale = Vector3.one
        this.selectTwo.transform.localPosition=Vector3.zero;
        this.selectTwo:SetActive(true)
    elseif curIndex==3 then
        this.selectThree .transform:SetParent(diffmonsterGOList[index].transform)
        this.selectThree.transform.localScale = Vector3.one
        this.selectThree.transform.localPosition=Vector3.zero;
        this.selectThree:SetActive(true)
    end
end

--点击取消
function this.SelectUnUpdata(index)
    for i = 1, #selectPokemonIdList do
        if selectPokemonIdList[i][2]==index then
            table.remove(selectPokemonIdList,i)
            
            diffmonsterUnGOList[index]:SetActive(false)
            return
        end
    end
end

return DiffmonsterEditPopup