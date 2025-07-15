--[[
    异妖解印界面
--]]
require("Base/BasePanel")
DemonActivatePanel = Inherit(BasePanel)
local this = DemonActivatePanel
local demonDataConfig = ConfigManager.GetConfig(ConfigName.DifferDemonsConfig)

-- 当前点选异妖信息
local pokemon = {}
-- 锁定组件列表
local lockCompList = {}
-- 解锁组件列表
local getCompList = {}

local orginLayer
local kInitLevel = 1

local demonImgInfo = {
    [1] = "live2d_s_jieling_dlg_3010",
    [2] = "live2d_s_jieling_zlz_3001",
    [3] = "live2d_s_jieling_hg_3002",
    [4] = "live2d_s_jieling_jhj_3003",
    [5] = "live2d_s_jieling_hs_3006",
    [6] = "live2d_s_jieling_lms_3009",
    [7] = "live2d_s_jieling_sl_3005",
    [8] = "live2d_s_jieling_md_3007",
    [9] = "live2d_s_jieling_fl_3008",
    [10] = "live2d_s_jieling_tl_3004",
}


--初始化组件（用于子类重写）
function DemonActivatePanel:InitComponent()
    orginLayer = 0
    this.btnBack = Util.GetGameObject(self.gameObject, "effect/UI/btnBack")
    this.btnBack2 = Util.GetGameObject(self.gameObject, "effect2/backBtn")

    this.circle = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao/effect_YiYao_neiquan")-- 内圈
    this.particle = Util.GetGameObject(self.gameObject, "effect/EFFECT")-- 组件界面粒子特效
    -- 组件, 3个组件删除3
    for i = 1, 4 do
        lockCompList[i] = Util.GetGameObject(self.gameObject, "compRoot/icon_weijihuo" .. i)
        getCompList[i] = Util.GetGameObject(self.gameObject, "compRoot/icon_jihuo" .. i)
    end

    this.diffIcon = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao/YiYao_icon"):GetComponent("Image")
    this.btnJieYin = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao/effect_YiYao_jieyin/effect_YiYao_jieyin") -- 解印按钮
    this.yiYaoFuWen = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao/effect_YiYao_fuwen") -- 显示符文
    this.openLockEffect = Util.GetGameObject(self.gameObject, "effect/UI/Effect_jiesuo")-- 解锁界面特效
    this.demonName = Util.GetGameObject(self.gameObject, "effect2/fx_ui_Effect_YiYao_JF/effect_YiYao_name/Text") -- 异妖名字
    this.yiyaoEffect = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao") -- 组件界面
    this.bg = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao/effect_YiYao_Beijing")
    this.live2dRoot = Util.GetGameObject(self.gameObject, "effect2/fx_ui_Effect_YiYao_JF/lieve2dRoot")
    this.tishiText1 = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao/tishiText1"):GetComponent("Text")

    --this.lookOverBtn = Util.GetGameObject(self.gameObject, "effect/UI/fx_ui_Effect_YiYao/lookOverBtn")

    screenAdapte(this.bg)
    screenAdapte(Util.GetGameObject(self.gameObject, "effect2/fx_ui_Effect_YiYao_JF/effect_YiYao_Beijing"))
    self.effect = Util.GetGameObject(self.gameObject, "effect")
    self.effect2 = Util.GetGameObject(self.gameObject, "effect2")

    -- 设置当前异妖技能信息
    this.skillInfo = Util.GetGameObject(self.gameObject, "effect/UI/skillInfo")
    this.skillIcon = Util.GetGameObject(this.skillInfo, "skillIcon"):GetComponent("Image")
    this.skillName = Util.GetGameObject(this.skillInfo, "skillNameBg/skillName"):GetComponent("Text")
    this.skillDesc = Util.GetGameObject(this.skillInfo, "skillDesc"):GetComponent("Text")


    this.intelligenceImage=Util.GetGameObject(self.gameObject,"effect2/fx_ui_Effect_YiYao_JF/intelligenceBg"):GetComponent("Image")
    this.intelligenceValue = Util.GetGameObject(self.gameObject, "effect2/fx_ui_Effect_YiYao_JF/intelligenceBg/value"):GetComponent("Text")

end

--绑定事件（用于子类重写）
function DemonActivatePanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.DiffMonsterPanel)

    end)
    Util.AddClick(this.btnBack2, function()
        self:ClosePanel()
        local pokemonInfoList = DiffMonsterManager.pokemonList
        UIManager.OpenPanel(UIName.DemonInfoPanel, { pokemon = pokemonInfoList[pokemon.id] })
    end)

    Util.AddClick(this.btnJieYin, function()
        local curPokemonData = DiffMonsterManager.GetSinglePokemonData(pokemon.id)
        if curPokemonData and curPokemonData.stage == 0 then
            --有数据  等级为零
            NetManager.DemonUpRequest(pokemon.id, function()
                DiffMonsterManager.UpdatePokemonLv(pokemon.id, 1)
                this.openLockEffect:SetActive(true) -- 播放闪光
                local timer0 = Timer.New(function()
                    this.yiyaoEffect:SetActive(false)
                end, 0.35)
                timer0:Start()
                local timer = Timer.New(function()
                    -- 设置激活界面的显示
                    this.SetGetPanelState(pokemon)
                    self.effect2:SetActive(true)
                    this.particle:SetActive(false)

                    SoundManager.PlaySound(SoundConfig.Sound_Dispelling)
                end, 0.4)
                timer:Start()
            end)
        end
    end)

    --Util.AddClick(this.lookOverBtn, function()
    --    UIManager.OpenPanel(UIName.DiffMonsterPreviewPanel, pokemon)
    --end)

end

--添加事件监听（用于子类重写）
function DemonActivatePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.DiffMonster.OnComponentChange, this.UpDataComponentInfo)
end

--移除事件监听（用于子类重写）
function DemonActivatePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.DiffMonster.OnComponentChange, this.UpDataComponentInfo)
end

function this.UpDataComponentInfo(_pokemonId)
    pokemon = DiffMonsterManager.GetSinglePokemonData(_pokemonId)
    this.UpdatePokemonPeiJianData()
end

--界面打开时调用（用于子类重写）
--args = {pokemon}
function DemonActivatePanel:OnOpen(args)
    pokemon = args.pokemon

    PlayUIAnim(this.btnJieYin.transform.parent)

    this.tishiText1.text = GetLanguageStrById(10440) .. GetLanguageStrById(10441) .. GetLanguageStrById(10442) .. pokemon.pokemonConfig.Name
    self.effect2:SetActive(false)
    this.yiyaoEffect:SetActive(true)
    this.btnJieYin.transform.parent.gameObject:SetActive(false)
end

function DemonActivatePanel:OnShow()
    this.UpdatePokemonPeiJianData()
    this.SetDemonSkillInfo()
end

function this.SetDemonSkillInfo()
    local skillId = pokemon.pokemonUpLvConfigList[kInitLevel].configData.SkillId
    local skillConfig = ConfigManager.TryGetConfigData(ConfigName.SkillConfig, skillId)
    if skillConfig then
        this.skillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
        this.skillName.text = GetLanguageStrById(skillConfig.Name)
        this.skillDesc.text = GetSkillConfigDesc(skillConfig)
    end
end



function DemonActivatePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(self.effect2, self.sortingOrder - orginLayer)
    for i = 1, 4 do
        getCompList[i]:GetComponent("Canvas").sortingOrder = self.sortingOrder + 21
    end
    orginLayer = self.sortingOrder
end

function this.UpdatePokemonPeiJianData()
    -- 配件显示
    local peijianHaveNum = 0
    this.yiYaoFuWen:SetActive(true)
    for i = 1, #lockCompList do
        local isActive = false
        -- 异妖组件的数量
        local curDemonCompNum = #pokemon.pokemoncomonpentList
        if curDemonCompNum >= i then
            local item = pokemon.pokemoncomonpentList[i]
            Util.GetGameObject(lockCompList[i], "icon"):GetComponent("Image").sprite = SetIcon(item.id)
            Util.GetGameObject(getCompList[i], "add/icon"):GetComponent("Image").sprite = SetIcon(item.id)
        end

        if curDemonCompNum >= i then
            local item = pokemon.pokemoncomonpentList[i]
            local addbtn = Util.GetGameObject(getCompList[i], "add")
            local componentInfo = Util.GetGameObject(getCompList[i], "componentInfo")
            Util.GetGameObject(getCompList[i],"iconBg"):GetComponent("Image").sprite = SetFrame(item.id)
            if item.level > 0 then  -- 已获得，可升级
                getCompList[i]:SetActive(true)
                isActive = true
                Util.GetGameObject(componentInfo, "icon"):GetComponent("Image").sprite = SetIcon(item.id)
                Util.GetGameObject(componentInfo, "levelBg/value"):GetComponent("Text").text = "+" .. item.level
                Util.GetGameObject(componentInfo, "upLvFlag").gameObject:SetActive(this.JudgeComponentCanBeUpData(item))
                lockCompList[i]:SetActive(false)
                addbtn:SetActive(false)
                componentInfo:SetActive(true)
                peijianHaveNum = peijianHaveNum + 1
                Util.AddOnceClick(Util.GetGameObject(getCompList[i],"componentInfo/icon"), function()

                    UIManager.OpenPanel(UIName.DemonPartsUpStarPanel, pokemon, 1, i)
                end)
            else  -- 未获得, 可解锁
                if BagManager.GetItemCountById(item.id) > 0 then
                    getCompList[i]:SetActive(true)
                    isActive = true
                    lockCompList[i]:SetActive(false)
                    addbtn:SetActive(true)
                    componentInfo:SetActive(false)
                    Util.AddOnceClick(addbtn, function()
                        NetManager.DemonCompUpRequest(pokemon.id, item.id, function()
                            addbtn:SetActive(false)
                            --BagManager.UpdateItemsNum(item.id, 1)
                            DiffMonsterManager.UpdatePokemonPeiJianLv(pokemon.id, item.id, 1)
                            this.UpdatePokemonPeiJianData()
                            UIManager.OpenPanel(UIName.DemonPartsActiveSuccessPanel, { pokemon = pokemon, index = i })
                            -- 播放声音
                            SoundManager.PlaySound(SoundConfig.Sound_Dispelling_01)
                        end)
                    end)
                else
                    getCompList[i]:SetActive(false)
                    isActive = false
                    lockCompList[i]:SetActive(true)
                    lockCompList[i]:GetComponent("Image").sprite = SetFrame(item.id)
                    Util.AddClick(Util.GetGameObject(lockCompList[i], "componentNeedInfo/icon"), function()
                        JumpManager.GoJump(21002)
                    end)
                end
            end
        else
            lockCompList[i]:SetActive(false)
            isActive = false
            getCompList[i]:SetActive(false)
        end
        Util.SetGray(lockCompList[i], not isActive)
    end
    if #pokemon.pokemoncomonpentList <= peijianHaveNum then
        this.btnJieYin.transform.parent.gameObject:SetActive(true)
        this.yiYaoFuWen:SetActive(false)
    end
    this.diffIcon.sprite = Util.LoadSprite(DiffMonsterIconDef[pokemon.id])
    this.diffIcon:SetNativeSize()
end

--界面关闭时调用（用于子类重写）
function DemonActivatePanel:OnClose()
    for i = 1, 4 do
        getCompList[i]:SetActive(false)
        lockCompList[i]:SetActive(false)
    end
    this.openLockEffect:SetActive(false)
    this.particle:SetActive(true)

    if this.LiveName then
        poolManager:UnLoadLive(this.LiveName, this.LiveGO)
        this.LiveName = nil
    end
end

--界面销毁时调用（用于子类重写）
function DemonActivatePanel:OnDestroy()
end

-- 根据当前点选的异妖信息初始化组件
function this.InitCompState(compNum)


    -- 根据异妖的组件状态设置组件的显示方式和激活按钮
    --this.SetCompShowState(pokemon, compNum)
end

function this.SetCompShowState(pokemon, num)
    -- 先激活HG
    if pokemon.id == 3 then
        for i = 1, num do
            lockCompList[i]:SetActive(false)
            getCompList[i]:SetActive(true)
        end
    end
end

function this.SetGetPanelState(pokemon)
    this.demonName:GetComponent("Text").text = pokemon.pokemonConfig.Name
    if this.LiveName then
        poolManager:UnLoadLive(this.LiveName, this.LiveGO)
        this.LiveName = nil
    end

    this.LiveName = DiffMonsterManager.demonlive2dInfo[pokemon.id].Name

    -- 加载立绘
    local scale = Vector3.New(demonDataConfig[pokemon.id].Scale, demonDataConfig[pokemon.id].Scale, demonDataConfig[pokemon.id].Scale)
    local position = Vector2.New(demonDataConfig[pokemon.id].Position[1], demonDataConfig[pokemon.id].Position[2])
    this.LiveGO = poolManager:LoadLive(demonImgInfo[pokemon.id], this.live2dRoot.transform,
    scale, Vector3.zero)
    this.LiveGO:GetComponent("RectTransform").anchoredPosition = position

    local pokemonConfig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, pokemon.id)
    this.intelligenceImage.sprite=GetQuantityImage(pokemonConfig.Aptitude)
    this.intelligenceValue.text = pokemonConfig.Aptitude
end

function this.JudgeComponentCanBeUpData(componentInfo)
    local maxLv = #componentInfo.upLvMateriaConfiglList
    local currentLv = componentInfo.level + 1
    if currentLv >= maxLv then
        return false
    else
        local materialEnough = true
        local costMaterials = componentInfo.upLvMateriaConfiglList[currentLv].Cost
        for idx = 1, #costMaterials do
            materialEnough = materialEnough and this.MaterialEnoughOrNot(costMaterials[idx][1], costMaterials[idx][2])
        end
        return materialEnough
    end
end

function this.MaterialEnoughOrNot(propId, needNumber)
    local ownNumber = BagManager.GetItemCountById(propId)
    return ownNumber >= needNumber
end

function this.ClickLockComponent(index)
    local propId = pokemon.pokemonConfig.ComonpentList[index]
    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, propId)
end

return DemonActivatePanel