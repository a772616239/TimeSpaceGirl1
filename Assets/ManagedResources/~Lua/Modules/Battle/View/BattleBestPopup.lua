require("Base/BasePanel")
local BattleBestPopup = Inherit(BasePanel)
local this = BattleBestPopup
local func2 = nil
--此回调目前只有大闹天宫试炼节点用  当有没有事件时  关闭按钮不好使
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local Limit20=20
local Limit30=30


local lowPlayerLv10=14
local lowPlayerLv20=20
local lowPlayerLv30=30
local lowPlayerLv40=40

local Limit10PerLv=7
local Limit20PerLv=4
local Limit30PerLv=3
local MaxLimit10PerLv=2

-- local Limit10PerLv=1
-- local Limit20PerLv=1
-- local Limit30PerLv=1
-- local MaxLimit10PerLv=1
function this:InitComponent()
    this.firstPanel = Util.GetGameObject(self.transform, "first")
    this.firstRole = Util.GetGameObject(this.firstPanel, "root") --m5
    this.firstName = Util.GetGameObject(self.transform, "name"):GetComponent("Text")
    this.firstDamage = Util.GetGameObject(self.transform, "hurt/damage"):GetComponent("Text")
    this.firstRate = Util.GetGameObject(self.transform, "hurt/rate"):GetComponent("Text")
    this.MaskBtn = Util.GetGameObject(self.transform, "Mask")
end

--绑定事件（用于子类重写）
function BattleBestPopup:BindEvent()
    Util.AddClick(
        this.MaskBtn,
        function()
            if func2 then
                self:ClosePanel()
            end
        end
    )
end

function this:OnOpen(heroTId, damageValue, allDamage, func, _func2, isShowStatistic)
    if UIManager.IsOpen(UIName.PublicGetHeroPanel) then
        UIManager.ClosePanel(UIName.PublicGetHeroPanel)
    end
    Time.timeScale = 1
    SoundManager.SetAudioSpeed(1)
    func2 = _func2
    -- 创建立绘
    if heroTId == 1 or heroTId == 2 then
        heroTId = 10001
    end
    heroTData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroTId)
    this.liveNode = LoadHerolive(heroTData, this.firstRole.transform)

    -- 名称
    this.firstName.text = GetLanguageStrById(heroTData.ReadingName)
    -- 伤害数值
    this.firstDamage.text = damageValue
    -- 伤害占比
    local rateValue =
        allDamage == 0 and "0%" or string.format("(%s%%)", math.floor(damageValue / allDamage * 10000) / 100)

    -- 结束回调
    this._OverFunc = func
    -- 开始播放动画
    Timer.New(
        function()
            if this._OverFunc then
                this._OverFunc(this)
            end
        end,
        1,
        1,
        true
    ):Start()
    Game.GlobalEvent:DispatchEvent( BattleEventName.BattleEndClearSceneRoles)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if this.liveNode then
        UnLoadHerolive(heroTData, this.liveNode)
        this.liveNode = nil
        Util.ClearChild(this.firstRole.transform)
    end

    if func2 then
        func2()
        func2 = nil
    end
    Log("PassTimes1:"..PassTimes1)
    if PlayerManager.level < lowPlayerLv10 then
        -- -- 30级之前不弹出评价
        -- if PassTimes1 % Limit10PerLv == 0 and ShowReviewPTimes <= 1 then
        --     -- 每四次弹出一次评价
        --     ReviewMgr:AllInOneFlowClick()

        --     ShowReviewPTimes = ShowReviewPTimes + 1

        --     PassTimes1 = 0
        -- end
    elseif PlayerManager.level < lowPlayerLv20 then
        if 
        -- PassTimes1 % Limit20PerLv == 0 and
        PassTimes1>1 and 
        ShowReviewPTimes <= 1 
        then
            -- 每四次弹出一次评价
            ReviewMgr:AllInOneFlowClick()
            ShowReviewPTimes = ShowReviewPTimes + 1

            PassTimes1 = 0
        end
    elseif PlayerManager.level < lowPlayerLv40 then
        if PassTimes1 % Limit30PerLv == 0 and ShowReviewPTimes <= 1 then
            -- 每四次弹出一次评价
            ReviewMgr:AllInOneFlowClick()
            ShowReviewPTimes = ShowReviewPTimes + 1

            PassTimes1 = 0
        end
    else
        if PassTimes1 % MaxLimit10PerLv == 0 and ShowReviewPTimes <= 1 then
            -- 每四次弹出一次评价
            ReviewMgr:AllInOneFlowClick()
            ShowReviewPTimes = ShowReviewPTimes + 1

            PassTimes1 = 0
        end
    end

    PassTimes1 = PassTimes1 + 1
end

return this
