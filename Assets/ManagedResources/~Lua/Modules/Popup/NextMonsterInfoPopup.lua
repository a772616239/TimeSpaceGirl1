require("Base/BasePanel")
NextMonsterInfoPopup = Inherit(BasePanel)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local this = NextMonsterInfoPopup
this.monsterInfoList = {}
this.rewardList = {}
this.grid = {}
local callBack
--初始化组件（用于子类重写）
function NextMonsterInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "InfoRoot/btnBack")
    for i = 1, 5 do
        this.monsterInfoList[i] = Util.GetGameObject(self.gameObject, "InfoRoot/infoRoot/grid/Item_" .. i)
        this.grid[i] = Util.GetGameObject(this.monsterInfoList[i], "bg/rewardRect/grid")
    end
end

--绑定事件（用于子类重写）
function NextMonsterInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
        if callBack then callBack() end
    end)
end

--添加事件监听（用于子类重写）
function NextMonsterInfoPopup:AddListener()

end

--移除事件监听（用于子类重写）
function NextMonsterInfoPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function NextMonsterInfoPopup:OnOpen(func)
    this.InitShowReward()
    this.InitMonsterShow()
    if func then
        callBack = func
    end
end

-- 初始化奖励显示
function this.InitShowReward()
    for i = 1, 5 do
        this.monsterInfoList[i]:SetActive(false)
        if not this.rewardList[i] then
            this.rewardList[i] = {}
            for j = 1, 6 do
                this.rewardList[i][j] = SubUIManager.Open(SubUIConfig.ItemView, this.grid[i].transform)
                this.rewardList[i][j].gameObject:SetActive(false)
            end
        end
    end
end

function this.InitMonsterShow()
    local monsterInfo = MonsterCampManager.GetNextWaveMonsterInfo()
    local curWave = MonsterCampManager.monsterWave
    for i = 1, 5 do   -- 5 只妖怪
        if not monsterInfo[i + curWave] then
            return
        end
        local waveNum = Util.GetGameObject(this.monsterInfoList[i], "bg/num"):GetComponent("Text")
        local icon = Util.GetGameObject(this.monsterInfoList[i], "bg/frame/icon"):GetComponent("Image")
        local name = Util.GetGameObject(this.monsterInfoList[i], "bg/nameFrame/name"):GetComponent("Text")
        local rewardData = monsterInfo[i + curWave].rewardShow

        waveNum.text = GetLanguageStrById(10311) ..curWave + i .. GetLanguageStrById(10316)
        icon.sprite = monsterInfo[i + curWave].icon
        name.text = monsterInfo[i + curWave].name

        -- 显示奖励
        for j = 1, #rewardData do
            local item = {}
            local itemId = rewardData[j][1]
            item[#item + 1] = itemId
            item[#item + 1] = rewardData[j][2]

            this.rewardList[i][j]:OnOpen(false, item, 0.9)
            this.rewardList[i][j].gameObject:SetActive(true)
        end
        this.monsterInfoList[i]:SetActive(true)
    end
end

--界面关闭时调用（用于子类重写）
function NextMonsterInfoPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function NextMonsterInfoPopup:OnDestroy()
    this.monsterInfoList = {}
    this.rewardList = {}
end

return NextMonsterInfoPopup