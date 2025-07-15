require("Base/BasePanel")
DiffMonsterPanel = Inherit(BasePanel)
local this = DiffMonsterPanel

-- 所有异妖信息列表
local pokemonInfoList = {}
this.demonlive2dInfo = {
    [1] = { Name = "live2d_s_jieling_dlg_3010",
            Scale = Vector3.New(0.24, 0.24, 1),
            Position = Vector2.New(24, -74), },
    [2] = { Name = "live2d_s_jieling_zlz_3001",
            Scale = Vector3.New(0.19, 0.19, 1),
            Position = Vector2.New(-4, -56), },
    [3] = { Name = "live2d_s_jieling_hg_3002",
            Scale = Vector3.New(0.5, 0.5, 1),
            Position = Vector2.New(-13, -86), },
    [4] = { Name = "live2d_s_jieling_jhj_3003",
            Scale = Vector3.New(0.5, 0.5, 1),
            Position = Vector2.New(7, -159), },
    [5] = { Name = "live2d_s_jieling_hs_3006",
            Scale = Vector3.New(0.22, 0.22, 1),
            Position = Vector2.New(15, -35), },
    [6] = { Name = "live2d_s_jieling_lms_3009",
            Scale = Vector3.New(-0.38, 0.38, 1),
            Position = Vector2.New(42, -75), },
    [7] = { Name = "live2d_s_jieling_sl_3005",
            Scale = Vector3.New(-0.45, 0.45, 1),
            Position = Vector2.New(-27, -57), },
    [8] = { Name = "live2d_s_jieling_md_3007",
            Scale = Vector3.New(-0.5, 0.5, 1),
            Position = Vector2.New(50, 21), },
    [9] = { Name = "live2d_s_jieling_fl_3008",
            Scale = Vector3.New(0.5, 0.5, 1),
            Position = Vector2.New(112, 25), },
    [10] = { Name = "live2d_s_jieling_tl_3004",
             Scale = Vector3.New(-0.4, 0.4, 1),
             Position = Vector2.New(-24, -93), },

}
-- 异妖父节点字符列表，下标对应异妖数据列表
this.DemonString = {
    [1] = "DLG", [2] = "ZLZ", [3] = "HG", [4] = "JHJ", [5] = "HS", [6] = "LMS", [7] = "SL", [8] = "MD", [9] = "FL", [10] = "TL",
}

-- 异妖名字
this.Name = {
    [1] = GetLanguageStrById(10458), [2] = GetLanguageStrById(10459), [3] = GetLanguageStrById(10460), [4] = GetLanguageStrById(10461), [5] = GetLanguageStrById(10462), [6] = GetLanguageStrById(10463), [7] = GetLanguageStrById(10464), [8] = GetLanguageStrById(10465), [9] = GetLanguageStrById(10466), [10] = GetLanguageStrById(10467),
}
-- 异妖名字
this.DemonName = {}
-- 异妖未激活图片
this.LockImg = {}
-- 激活异妖图片
this.GetImg = {}
-- 异妖红点
this.DemonRedPoint = {}
-- 异妖进阶提示
this.upGradFlag = {}

this.DemonGOList = {}

local kMultiplyPower = 5
local orginLayer
--初始化组件（用于子类重写）
function DiffMonsterPanel:InitComponent()

    orginLayer = 0
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.textPokemon = Util.GetGameObject(self.gameObject, "demonNumRoot/Image/Text"):GetComponent("Text")-- 异妖数量显示
    -- 10个阔爱的异妖
    for i = 1, 10 do
        -- 已经激活的异妖图片
        this.GetImg[i] = Util.GetGameObject(self.gameObject, "DemonRoot/" .. this.DemonString[i] .. "/GetImg")
        -- 未解锁的异妖图片
        this.LockImg[i] = Util.GetGameObject(self.gameObject, "DemonRoot/" .. this.DemonString[i] .. "/LockImg")
        this.DemonName[i] = Util.GetGameObject(self.gameObject, "DemonRoot/" .. this.DemonString[i] .. "/name/Text"):GetComponent("Text")
        this.DemonRedPoint[i] = Util.GetGameObject(self.gameObject, "DemonRoot/" .. this.DemonString[i] .. "/name/redPoint")
        this.upGradFlag[i] = Util.GetGameObject(self.gameObject, "DemonRoot/" .. this.DemonString[i] .. "/upGradFlag")
    end

    this.warPower = Util.GetGameObject(self.gameObject, "powerBtn/value"):GetComponent("Text")
    this.warPowerBtn = Util.GetGameObject(self.gameObject, "powerBtn")

    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    --this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)-- 货币显示

    self.bg = Util.GetGameObject(self.gameObject, "effect")
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    screenAdapte(self.bg)
end

--绑定事件（用于子类重写）
function DiffMonsterPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        --UIManager.OpenPanel(UIName.MainPanel)
    end)

    Util.AddClick(this.warPowerBtn, function()
        if table.nums(DiffMonsterManager.GetAllActiveDiffComponents()) <= 0 then
            PopupTipPanel.ShowTipByLanguageId(10468)
            return
        end
        UIManager.OpenPanel(UIName.DiffMonsterAttributeAdditionPanel)
    end)

    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.DiffMonster, this.helpPosition.x, this.helpPosition.y)
    end)
end

--添加事件监听（用于子类重写）
function DiffMonsterPanel:AddListener()

end

--移除事件监听（用于子类重写）
function DiffMonsterPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function DiffMonsterPanel:OnOpen(...)

    pokemonInfoList = DiffMonsterManager.pokemonList
    for i = 1, #pokemonInfoList do
        local pokemon = pokemonInfoList[i]
        this.DemonRedPoint[i]:SetActive(DiffMonsterManager.GetSingleDiffMonsterRedPointStatus(pokemon))
        if pokemon.stage > 0 then
            -- 如果异妖已经激活
            this.DemonName[i].text = string.format("<color=#FAF8F5FF>%s</color>", this.Name[i])
            this.LockImg[i].gameObject:SetActive(false)
            this.GetImg[i].gameObject:SetActive(true)
            this.upGradFlag[i].gameObject:SetActive(this:GetDiffMonsterUpGradCondition(i))
            this.DemonGOList[i] = poolManager:LoadLive(this.demonlive2dInfo[i].Name, this.GetImg[i].transform, this.demonlive2dInfo[i].Scale, Vector3.zero)
            this.DemonGOList[i]:GetComponent("RectTransform").anchoredPosition = this.demonlive2dInfo[i].Position
        end
    end
    this.textPokemon.text = string.format(GetLanguageStrById(10469), self:GetActiveDiffMonsterCount(), #pokemonInfoList)
    -- 绑定所有未解锁异妖图片
    for i = 1, #pokemonInfoList do
        Util.AddOnceClick(this.LockImg[i], function()
            this.OpenPanelUpToStageAndComp(i)
        end)
    end
    -- 点击已经解锁的异妖图片事件
    for i = 1, #pokemonInfoList do
        Util.AddOnceClick(this.GetImg[i], function()
            this.OpenPanelUpToStageAndComp(i)
        end)
    end

    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.DiffMonster })
    --this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.DiffMonsterPanel })

    SoundManager.PlayMusic(SoundConfig.BGM_DiffMonster)

    -- 刷新红点状态
    CheckRedPointStatus(RedPointType.DiffMonster)
end

function DiffMonsterPanel:OnShow()
    self:SetWarPower()
end

function DiffMonsterPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function DiffMonsterPanel:GetActiveDiffMonsterCount()
    local activeNum = 0
    table.walk(pokemonInfoList, function(pokemonInfo)
        if pokemonInfo.stage > 0 then
            activeNum = activeNum + 1
        end
    end)
    return activeNum
end

--判断异妖是否可以进阶
function DiffMonsterPanel:GetDiffMonsterUpGradCondition(index)
    local pokeMon = pokemonInfoList[index]
    --local meetCondition = true
    --table.walk(pokeMon.pokemoncomonpentList, function(componentInfo)
    --    meetCondition = meetCondition and componentInfo.level > pokeMon.stage
    --end)
    --return meetCondition
    return DiffMonsterManager.SingleUpGradDiffMonster(pokeMon)
end

--界面关闭时调用（用于子类重写）
function DiffMonsterPanel:OnClose()

    for i = 1, #pokemonInfoList do
        local pokemon = pokemonInfoList[i]
        if pokemon.stage > 0 then
            if this.DemonGOList[i] then
                poolManager:UnLoadLive(this.demonlive2dInfo[i].Name, this.DemonGOList[i])
                this.DemonGOList[i] = nil
            end
        end
    end
end

--界面销毁时调用（用于子类重写）
function DiffMonsterPanel:OnDestroy()

    SubUIManager.Close(this.UpView)
    --SubUIManager.Close(this.BtView)
end
--根据异妖组件数量状态选择打开面板
function this.OpenPanelUpToStageAndComp(_index)
    -- 如果当前异妖已经激活
    if pokemonInfoList[_index].stage > 0 then
        UIManager.OpenPanel(UIName.DemonInfoPanel, { pokemon = pokemonInfoList[_index] })
    else
        UIManager.OpenPanel(UIName.DemonActivatePanel, { pokemon = pokemonInfoList[_index] })
    end
end

--计算战力
function DiffMonsterPanel:SetWarPower()
    this.warPower.text = DiffMonsterManager.GetDiffMonstersPowerValue()
end

return DiffMonsterPanel