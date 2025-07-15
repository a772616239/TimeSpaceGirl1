require("Base/BasePanel")
local AdventureGetRewardPopup = Inherit(BasePanel)
local this = AdventureGetRewardPopup

this.selfsortingOrder = 0
--初始化组件（用于子类重写）
function AdventureGetRewardPopup:InitComponent()
    this.btnBack1 = Util.GetGameObject(self.transform, "pageOne/btnBack")
    this.btnBack2 = Util.GetGameObject(self.transform, "pageTwo/btnBack")
    this.pageOne = Util.GetGameObject(self.transform, "pageOne")
    this.pageTwo = Util.GetGameObject(self.transform, "pageTwo")
    this.numLab1 = Util.GetGameObject(self.transform, "pageOne/content1/top/finishAttackNumberText")
    this.numLab2 = Util.GetGameObject(self.transform, "pageTwo/content2/top/finishAttackNumberText")
    this.hurtLab1 = Util.GetGameObject(self.transform, "pageOne/content1/top/Text/injury")
    this.hurtLab2 = Util.GetGameObject(self.transform, "pageTwo/content2/top/Text/injury")
    this.grid = Util.GetGameObject(self.transform, "pageOne/content1/bottom/scrollRect/grid")
    this.slider = Util.GetGameObject(self.transform, "pageTwo/Slider"):GetComponent("Slider")
    this.sliderText = Util.GetGameObject(self.transform, "pageTwo/Slider/Text"):GetComponent("Text")

    this.btnResult1 = Util.GetGameObject(self.transform, "pageOne/btnResult")
    this.btnResult2 = Util.GetGameObject(self.transform, "pageTwo/btnResult")
end

--绑定事件（用于子类重写）
function AdventureGetRewardPopup:BindEvent()
    Util.AddClick(this.btnBack1, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.btnBack2, function()
        this:ClosePanel()
    end)

    Util.AddClick(this.btnResult1, function()
        UIManager.OpenPanel(UIName.DamageResultPanel, 1)
    end)
    Util.AddClick(this.btnResult2, function()
        UIManager.OpenPanel(UIName.DamageResultPanel, 0)
    end)
end

--添加事件监听（用于子类重写）
function AdventureGetRewardPopup:AddListener()
end

--移除事件监听（用于子类重写）
function AdventureGetRewardPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function AdventureGetRewardPopup:OnOpen(bossGroupIdId, challengeCount, hurt, result, killRewards,bossTotalHp,bossRemainHp )
    -- 正确性检测
    this.selfsortingOrder = self.sortingOrder
    if not bossGroupIdId then return end
    --
    local isDrop = result == 1
    this.numLab1:GetComponent("Text").text = string.format(GetLanguageStrById(10045), challengeCount)
    this.hurtLab1:GetComponent("Text").text = hurt
    this.numLab2:GetComponent("Text").text = string.format(GetLanguageStrById(10045), challengeCount)
    this.hurtLab2:GetComponent("Text").text = hurt
    --this.bg:GetComponent("RectTransform").sizeDelta = Vector2.New(910, isDrop and 625 or 425)
    if isDrop then
        this.pageTwo:SetActive(false)
        this.pageOne:SetActive(true)
        --local killerRewardId = monsterGroup[bossGroupIdId].Rewardgroup[1]
        this.GridAdapter(this.grid, killRewards)
    else
        this.pageTwo:SetActive(true)
        this.pageOne:SetActive(false)
        this.slider.value =bossRemainHp / bossTotalHp
        local remainlHP =bossRemainHp > 1000000 and math.floor(bossRemainHp/10000)..GetLanguageStrById(10042) or tostring(bossRemainHp)
        local totalHP =bossTotalHp > 1000000 and math.floor(bossTotalHp/10000)..GetLanguageStrById(10042) or tostring(bossTotalHp)
        this.sliderText.text = string.format("%s/%s", remainlHP, totalHP)
    end

    local isShowResult = BattleRecordManager.isHaveRecord()
    this.btnResult1:SetActive(isShowResult)
    this.btnResult2:SetActive(isShowResult)
end

-- 数据匹配
local _ItemViewList = {}
function this.GridAdapter(grid, killRewards)
    for _, item in ipairs(_ItemViewList) do
        item.gameObject:SetActive(false)
    end
    local itemDataList = {}
    local ss = string.split(killRewards, "|")
    for i=1, #ss do
        local arr = string.split(ss[i], "#")
        for j = 1, #arr do
            arr[j] = tonumber(arr[j])
        end
        table.insert(itemDataList, arr)
    end
    for i = 1, #itemDataList do
        if not _ItemViewList[i] then
            local view = SubUIManager.Open(SubUIConfig.ItemView,grid.transform)
            _ItemViewList[i] = view
        end
        _ItemViewList[i]:OnOpen(false, itemDataList[i], 1, false,false,false,this.selfsortingOrder)
        _ItemViewList[i].gameObject:SetActive(true)
    end
end
--界面关闭时调用（用于子类重写）
function AdventureGetRewardPopup:OnClose()
    for _, item in ipairs(_ItemViewList) do
        SubUIManager.Close(item)
    end
    _ItemViewList = {}

end

--界面销毁时调用（用于子类重写）
function AdventureGetRewardPopup:OnDestroy()
end

return AdventureGetRewardPopup